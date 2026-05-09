package observability

import (
	"context"
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/codes"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/trace"
	"google.golang.org/grpc/credentials/insecure"
)

const requestContextKey = "request_context"

func InitTracer(ctx context.Context, service, environment string) (func(context.Context) error, error) {
	otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(
		propagation.TraceContext{},
		propagation.Baggage{},
	))

	endpoint := strings.TrimSpace(os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT"))
	if endpoint == "" {
		provider := trace.NewNoopTracerProvider()
		otel.SetTracerProvider(provider)
		return func(context.Context) error { return nil }, nil
	}

	endpoint = strings.TrimPrefix(endpoint, "http://")
	endpoint = strings.TrimPrefix(endpoint, "https://")
	exporter, err := otlptracegrpc.New(ctx,
		otlptracegrpc.WithEndpoint(endpoint),
		otlptracegrpc.WithTLSCredentials(insecure.NewCredentials()),
	)
	if err != nil {
		return nil, err
	}

	res, err := resource.New(ctx,
		resource.WithAttributes(
			attribute.String("service.name", service),
			attribute.String("deployment.environment", environment),
		),
		resource.WithFromEnv(),
		resource.WithTelemetrySDK(),
		resource.WithHost(),
	)
	if err != nil {
		return nil, err
	}

	provider := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(exporter),
		sdktrace.WithResource(res),
	)
	otel.SetTracerProvider(provider)
	return provider.Shutdown, nil
}

func TracingMiddleware(service string) fiber.Handler {
	tracer := otel.Tracer(service)

	return func(c *fiber.Ctx) error {
		parent := otel.GetTextMapPropagator().Extract(context.Background(), fiberHeaderCarrier{ctx: c})
		route := c.Path()
		if fiberRoute := c.Route(); fiberRoute != nil && fiberRoute.Path != "" {
			route = fiberRoute.Path
		}

		ctx, span := tracer.Start(parent, c.Method()+" "+route,
			trace.WithSpanKind(trace.SpanKindServer),
			trace.WithAttributes(
				attribute.String("http.request.method", c.Method()),
				attribute.String("url.path", c.Path()),
				attribute.String("user_agent.original", c.Get(fiber.HeaderUserAgent)),
				attribute.String("http.route", route),
				attribute.String("client.address", c.IP()),
			),
		)
		c.Locals(requestContextKey, ctx)

		start := time.Now()
		err := c.Next()
		status := c.Response().StatusCode()
		span.SetAttributes(
			attribute.Int("http.response.status_code", status),
			attribute.Float64("http.server.duration_ms", float64(time.Since(start).Microseconds())/1000),
		)
		if err != nil {
			span.RecordError(err)
			span.SetStatus(codes.Error, err.Error())
		} else if status >= 500 {
			span.SetStatus(codes.Error, fmt.Sprintf("http status %d", status))
		}
		span.End()

		return err
	}
}

func RequestContext(c *fiber.Ctx) context.Context {
	if ctx, ok := c.Locals(requestContextKey).(context.Context); ok && ctx != nil {
		return ctx
	}
	return context.Background()
}

type fiberHeaderCarrier struct {
	ctx *fiber.Ctx
}

func (c fiberHeaderCarrier) Get(key string) string {
	return c.ctx.Get(key)
}

func (c fiberHeaderCarrier) Set(key, value string) {
	c.ctx.Set(key, value)
}

func (c fiberHeaderCarrier) Keys() []string {
	keys := make([]string, 0, len(c.ctx.GetReqHeaders()))
	for key := range c.ctx.GetReqHeaders() {
		keys = append(keys, key)
	}
	return keys
}
