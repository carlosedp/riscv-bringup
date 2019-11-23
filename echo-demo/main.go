package main

import (
    "net/http"
    "fmt"
    "runtime"

    "github.com/labstack/echo/v4"
)

func main() {
    os := runtime.GOOS
    arch := runtime.GOARCH
    output := fmt.Sprintf("Hello, I'm running Echo inside a container on %s/%s",os,arch)
    e := echo.New()
    e.GET("/", func(c echo.Context) error {
        return c.String(http.StatusOK, output)
    })
    e.Logger.Fatal(e.Start(":8080"))
}
