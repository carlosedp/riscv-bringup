package main

import (
	"encoding/binary"
	"io/ioutil"
	"log"
	"os"

	qrcode "github.com/skip2/go-qrcode"
)

func main() {
	input, err := ioutil.ReadAll(os.Stdin)
	if err != nil {
		log.Fatalf("Unable to read standard input: %s", err.Error())
	}
	png, err := qrcode.Encode(string(input), qrcode.Medium, 256)
	if err != nil {
		log.Fatalf("Unable to read standard input: %s", err.Error())
	}
	binary.Write(os.Stdout, binary.LittleEndian, png)
}
