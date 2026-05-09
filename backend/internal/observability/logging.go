package observability

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"os"
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"
	"go.opentelemetry.io/otel/trace"
)

type Logger struct {
	service     string
	environment string
	logger      *slog.Logger
}

func NewLogger(service, environment string) *Logger {
	handler := slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelInfo,
	})
	logger := slog.New(handler)
	slog.SetDefault(logger)

	return &Logger{
		service:     service,
		environment: environment,
		logger:      logger,
	}
}

func (l *Logger) Info(msg string, attrs ...slog.Attr) {
	l.logger.LogAttrs(context.Background(), slog.LevelInfo, msg, l.baseAttrs(attrs...)...)
}

func (l *Logger) Error(msg string, attrs ...slog.Attr) {
	l.logger.LogAttrs(context.Background(), slog.LevelError, msg, l.baseAttrs(attrs...)...)
}

func (l *Logger) Fatal(msg string, attrs ...slog.Attr) {
	l.Error(msg, attrs...)
	os.Exit(1)
}

func (l *Logger) baseAttrs(attrs ...slog.Attr) []slog.Attr {
	base := []slog.Attr{
		slog.String("service", l.service),
		slog.String("environment", l.environment),
	}
	return append(base, attrs...)
}

func (l *Logger) FiberRequestLogger() fiber.Handler {
	return func(c *fiber.Ctx) error {
		start := time.Now()
		err := c.Next()
		latency := time.Since(start)

		spanContext := trace.SpanContextFromContext(RequestContext(c))
		attrs := []slog.Attr{
			slog.String("http_request_method", c.Method()),
			slog.String("http_request_path", c.Path()),
			slog.String("http_request_route", routePath(c)),
			slog.Int("http_response_status", c.Response().StatusCode()),
			slog.Int64("http_request_latency_ms", latency.Milliseconds()),
			slog.String("http_request_user_agent", c.Get(fiber.HeaderUserAgent)),
			slog.String("http_request_remote_ip", c.IP()),
			slog.String("http_request_id", requestID(c)),
		}
		if spanContext.IsValid() {
			attrs = append(attrs,
				slog.String("trace_id", spanContext.TraceID().String()),
				slog.String("span_id", spanContext.SpanID().String()),
			)
		}
		if err != nil {
			attrs = append(attrs, slog.String("error", err.Error()))
		}

		level := slog.LevelInfo
		if c.Response().StatusCode() >= 500 || err != nil {
			level = slog.LevelError
		}
		l.logger.LogAttrs(context.Background(), level, "http_request", l.baseAttrs(attrs...)...)

		return err
	}
}

func requestID(c *fiber.Ctx) string {
	for _, header := range []string{"X-Request-Id", "X-Cloud-Trace-Context"} {
		if value := strings.TrimSpace(c.Get(header)); value != "" {
			return value
		}
	}
	return ""
}

func routePath(c *fiber.Ctx) string {
	if route := c.Route(); route != nil && route.Path != "" {
		return route.Path
	}
	return c.Path()
}

func JSONError(c *fiber.Ctx, code int, err error) error {
	payload := fiber.Map{"error": err.Error()}
	if marshaled, marshalErr := json.Marshal(payload); marshalErr == nil {
		c.Set(fiber.HeaderContentType, fiber.MIMEApplicationJSONCharsetUTF8)
		return c.Status(code).Send(marshaled)
	}
	return c.Status(code).SendString(fmt.Sprintf(`{"error":%q}`, err.Error()))
}
