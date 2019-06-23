all: build

build:
	go build -o echo-riscv -v

docker:
	DOCKER_BUILDKIT=1 docker build -t carlosedp/echo-riscv .
