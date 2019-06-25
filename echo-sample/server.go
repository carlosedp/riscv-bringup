package main

import (
	"net/http"
        "fmt"
        "runtime"
	"github.com/labstack/echo"
)

var name string

func main() {
	e := echo.New()
        os := runtime.GOOS
        arch := runtime.GOARCH
	e.GET("/", func(c echo.Context) error {
		url := c.QueryParams()
		fmt.Println(url)
		name = c.QueryParam("name")
		if name == "" {
			name = "World"
		}
		output := fmt.Sprintf("Hello, %s! I'm running on %s/%s inside a container!", name, os, arch)
		return c.String(http.StatusOK, output)
	})
	e.Logger.Fatal(e.Start(":8080"))
}

