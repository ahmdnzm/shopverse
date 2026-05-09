package main

import (
	"context"
	"log/slog"
	"os"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/cors"
	"github.com/gofiber/fiber/v2/middleware/recover"
	"github.com/shopverse/backend/internal/database"
	"github.com/shopverse/backend/internal/handlers"
	"github.com/shopverse/backend/internal/middleware"
	"github.com/shopverse/backend/internal/observability"
)

func main() {
	serviceName := getEnv("SERVICE_NAME", "shopverse-backend")
	environment := getEnv("ENVIRONMENT", "local")
	appLogger := observability.NewLogger(serviceName, environment)

	shutdownTracer, err := observability.InitTracer(context.Background(), serviceName, environment)
	if err != nil {
		appLogger.Fatal("tracing_initialization_failed", slog.String("error", err.Error()))
	}
	defer func() {
		if err := shutdownTracer(context.Background()); err != nil {
			appLogger.Error("tracing_shutdown_failed", slog.String("error", err.Error()))
		}
	}()

	database.Connect()

	app := fiber.New(fiber.Config{
		ErrorHandler: func(c *fiber.Ctx, err error) error {
			code := fiber.StatusInternalServerError
			if e, ok := err.(*fiber.Error); ok {
				code = e.Code
			}
			return observability.JSONError(c, code, err)
		},
	})

	app.Use(recover.New())
	app.Use(observability.TracingMiddleware(serviceName))
	app.Use(appLogger.FiberRequestLogger())

	metrics := observability.NewMetrics(serviceName, environment, database.SQLDB())
	app.Use(metrics.Middleware())

	frontendOrigin := os.Getenv("FRONTEND_ORIGIN")
	if frontendOrigin == "" {
		frontendOrigin = "http://localhost:3000"
	}

	allowCredentials := frontendOrigin != "*"

	app.Use(cors.New(cors.Config{
		AllowOrigins:     frontendOrigin,
		AllowMethods:     "GET,POST,PUT,DELETE,OPTIONS",
		AllowHeaders:     "Origin,Content-Type,Accept,Authorization",
		AllowCredentials: allowCredentials,
	}))

	app.Get("/health", func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{"status": "healthy"})
	})
	app.Get("/metrics", metrics.Handler())

	api := app.Group("/api")

	auth := api.Group("/auth")
	auth.Post("/register", handlers.Register)
	auth.Post("/login", handlers.Login)

	products := api.Group("/products")
	products.Get("/", handlers.GetProducts)
	products.Get("/:id", handlers.GetProduct)
	products.Post("/", middleware.Protected(), handlers.CreateProduct)

	cart := api.Group("/cart", middleware.Protected())
	cart.Get("/", handlers.GetCart)
	cart.Post("/", handlers.AddToCart)
	cart.Put("/:id", handlers.UpdateCartItem)
	cart.Delete("/:id", handlers.RemoveCartItem)

	orders := api.Group("/orders", middleware.Protected())
	orders.Get("/", handlers.GetOrders)
	orders.Post("/", handlers.CreateOrder)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	appLogger.Info("server_starting", slog.String("port", port))
	if err := app.Listen(":" + port); err != nil {
		appLogger.Fatal("server_failed", slog.String("error", err.Error()))
	}
}

func getEnv(key, fallback string) string {
	value := os.Getenv(key)
	if value == "" {
		return fallback
	}
	return value
}
