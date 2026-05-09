package observability

import (
	"database/sql"
	"strconv"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/valyala/fasthttp/fasthttpadaptor"
)

type Metrics struct {
	requestsTotal  *prometheus.CounterVec
	requestLatency *prometheus.HistogramVec
	inFlight       prometheus.Gauge
	dbStats        *prometheus.GaugeVec
	registry       *prometheus.Registry
	sqlDB          *sql.DB
}

func NewMetrics(service, environment string, sqlDB *sql.DB) *Metrics {
	constLabels := prometheus.Labels{
		"service":     service,
		"environment": environment,
	}

	m := &Metrics{
		registry: prometheus.NewRegistry(),
		sqlDB:    sqlDB,
		requestsTotal: prometheus.NewCounterVec(prometheus.CounterOpts{
			Name:        "shopverse_http_requests_total",
			Help:        "Total HTTP requests handled by the backend.",
			ConstLabels: constLabels,
		}, []string{"method", "route", "status"}),
		requestLatency: prometheus.NewHistogramVec(prometheus.HistogramOpts{
			Name:        "shopverse_http_request_duration_seconds",
			Help:        "HTTP request duration in seconds.",
			ConstLabels: constLabels,
			Buckets:     prometheus.DefBuckets,
		}, []string{"method", "route", "status"}),
		inFlight: prometheus.NewGauge(prometheus.GaugeOpts{
			Name:        "shopverse_http_requests_in_flight",
			Help:        "Number of backend HTTP requests currently in flight.",
			ConstLabels: constLabels,
		}),
		dbStats: prometheus.NewGaugeVec(prometheus.GaugeOpts{
			Name:        "shopverse_db_connections",
			Help:        "Database connection pool statistics.",
			ConstLabels: constLabels,
		}, []string{"state"}),
	}

	m.registry.MustRegister(m.requestsTotal, m.requestLatency, m.inFlight, m.dbStats)
	return m
}

func (m *Metrics) Middleware() fiber.Handler {
	return func(c *fiber.Ctx) error {
		if c.Path() == "/metrics" {
			return c.Next()
		}

		start := time.Now()
		m.inFlight.Inc()
		err := c.Next()
		m.inFlight.Dec()

		route := c.Path()
		if fiberRoute := c.Route(); fiberRoute != nil && fiberRoute.Path != "" {
			route = fiberRoute.Path
		}
		status := strconv.Itoa(c.Response().StatusCode())

		m.requestsTotal.WithLabelValues(c.Method(), route, status).Inc()
		m.requestLatency.WithLabelValues(c.Method(), route, status).Observe(time.Since(start).Seconds())
		m.observeDBStats()

		return err
	}
}

func (m *Metrics) Handler() fiber.Handler {
	handler := fasthttpadaptor.NewFastHTTPHandler(promhttp.HandlerFor(m.registry, promhttp.HandlerOpts{}))
	return func(c *fiber.Ctx) error {
		m.observeDBStats()
		handler(c.Context())
		return nil
	}
}

func (m *Metrics) observeDBStats() {
	if m.sqlDB == nil {
		return
	}

	stats := m.sqlDB.Stats()
	m.dbStats.WithLabelValues("open").Set(float64(stats.OpenConnections))
	m.dbStats.WithLabelValues("in_use").Set(float64(stats.InUse))
	m.dbStats.WithLabelValues("idle").Set(float64(stats.Idle))
	m.dbStats.WithLabelValues("wait_count").Set(float64(stats.WaitCount))
	m.dbStats.WithLabelValues("wait_duration_seconds").Set(stats.WaitDuration.Seconds())
	m.dbStats.WithLabelValues("max_idle_closed").Set(float64(stats.MaxIdleClosed))
	m.dbStats.WithLabelValues("max_lifetime_closed").Set(float64(stats.MaxLifetimeClosed))
}
