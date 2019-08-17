APP=echo-riscv
REPO=carlosedp
VERSION=latest
PLATFORMS=linux/amd64 linux/arm64 linux/riscv64

temp = $(subst /, ,$@)
os = $(word 1, $(temp))
arch = $(word 2, $(temp))
noop=
space = $(noop) $(noop)
comma = ,

all: $(PLATFORMS)

$(PLATFORMS):
	GOOS=$(os) GOARCH=$(arch) CGO_ENABLED=0 go build -a -installsuffix cgo -ldflags '-extldflags "-static"' -o ${APP}-$(os)-$(arch)

docker: $(PLATFORMS)
	docker buildx build -t ${REPO}/${APP} --platform=$(subst $(space),$(comma),$(PLATFORMS)) --push .

docker-legacy: $(PLATFORMS)
	DOCKER_BUILDKIT=1 docker build -t ${REPO}/${APP} .

docker-multi: $(PLATFORMS)
	$(foreach PLAT,$(PLATFORMS),$(shell DOCKER_BUILDKIT=1 docker build -t ${REPO}/${APP}:${}{VERSION} --platform=$(PLAT) .))

podman-build: $(PLATFORMS)
	sudo podman build -t ${REPO}/${APP} .

podman-run: podman-build
	sudo podman run -d --name echo --net host ${REPO}/${APP}

release: docker

clean:
	rm -rf ${APP}-*

.PHONY: all $(PLATFORMS) docker $(PLATFORMS)-docker clean
