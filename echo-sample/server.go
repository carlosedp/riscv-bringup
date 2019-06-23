package main

import (
	"net/http"
        "fmt"
        "runtime"
	"github.com/labstack/echo"
)

func main() {
	e := echo.New()
        os := runtime.GOOS
        arch := runtime.GOARCH
        output := fmt.Sprintf("Hello, World! I'm running on %s/%s inside a container!", os, arch)
	e.GET("/", func(c echo.Context) error {
		return c.String(http.StatusOK, output)
	})
	e.Logger.Fatal(e.Start(":8080"))
}

