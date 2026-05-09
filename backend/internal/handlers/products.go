package handlers

import (
	"log/slog"

	"github.com/gofiber/fiber/v2"
	"github.com/shopverse/backend/internal/database"
	"github.com/shopverse/backend/internal/models"
	"github.com/shopverse/backend/internal/observability"
)

func GetProducts(c *fiber.Ctx) error {
	var products []models.Product

	query := database.DB.WithContext(observability.RequestContext(c))

	if category := c.Query("category"); category != "" {
		query = query.Where("category = ?", category)
	}

	if search := c.Query("search"); search != "" {
		query = query.Where("name LIKE ?", "%"+search+"%")
	}

	if result := query.Order("created_at DESC").Find(&products); result.Error != nil {
		slog.Error("products_fetch_failed", slog.String("error", result.Error.Error()))
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": "Failed to fetch products",
		})
	}

	return c.JSON(products)
}

func GetProduct(c *fiber.Ctx) error {
	db := database.DB.WithContext(observability.RequestContext(c))
	id := c.Params("id")

	var product models.Product
	if result := db.First(&product, id); result.Error != nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{
			"error": "Product not found",
		})
	}

	return c.JSON(product)
}

func CreateProduct(c *fiber.Ctx) error {
	db := database.DB.WithContext(observability.RequestContext(c))

	var product models.Product
	if err := c.BodyParser(&product); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Invalid request body",
		})
	}

	if product.Name == "" || product.Price <= 0 {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Name and a positive price are required",
		})
	}

	if result := db.Create(&product); result.Error != nil {
		slog.Error("product_create_failed", slog.String("error", result.Error.Error()))
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": "Failed to create product",
		})
	}

	return c.Status(fiber.StatusCreated).JSON(product)
}
