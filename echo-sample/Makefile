all: build

build:
	CGO_ENABLED=0 go build -a -installsuffix cgo -ldflags '-extldflags "-static"' -o echo-riscv

docker:
	DOCKER_BUILDKIT=1 docker build -t carlosedp/echo-riscv .
