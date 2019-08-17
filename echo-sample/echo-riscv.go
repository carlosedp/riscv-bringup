package main

import (
	"fmt"
	"net/http"
	"runtime"

	"github.com/labstack/echo/v4/middleware"
	"github.com/labstack/echo/v4"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
	hitMetric = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "webserver_get_root",
		Help: "The total number GET calls on each path",
	}, []string{"code", "path"})

	name string
)

func init() {
	prometheus.Register(hitMetric)
}

// PromHitMetric is the middleware function to increase hit metric.
func PromHitMetric(next echo.HandlerFunc) echo.HandlerFunc {
	return func(c echo.Context) error {
		if err := next(c); err != nil {
			c.Error(err)
		}
		if c.Path() != "/metrics" {
			hitMetric.WithLabelValues(fmt.Sprintf("%d", http.StatusOK), c.Path()).Inc()
		}
		return nil
	}
}

func main() {
	e := echo.New()

	// Middleware
	e.Use(middleware.Logger())
	e.Use(PromHitMetric)

	// Application routes
	e.GET("/", rootHandler)
	e.GET("/test", testHandler)

	// Route to Prometheus Metrics
	e.GET("/metrics", echo.WrapHandler(promhttp.Handler()))
	e.Logger.Fatal(e.Start(":8080"))
}

// Handlers
func rootHandler(c echo.Context) error {
	os := runtime.GOOS
	arch := runtime.GOARCH
	name = c.QueryParam("name")
	if name == "" {
		name = "World"
	}
	output := fmt.Sprintf("Hello, %s! I'm running on %s/%s inside a container!", name, os, arch)
	return c.String(http.StatusOK, output)
}

func testHandler(c echo.Context) error {
	return c.String(http.StatusOK, "Test path")
}
