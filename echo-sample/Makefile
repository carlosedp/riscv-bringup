all: build

build:
	CGO_ENABLED=0 go build -a -installsuffix cgo -ldflags '-extldflags "-static"' -o echo-riscv

docker: build
	DOCKER_BUILDKIT=1 docker build -t carlosedp/echo_on_riscv .

podman-build: build
	sudo podman build -t echo_on_riscv .

podman-run: build
	sudo podman run -d --name echo --net host echo_on_riscv
