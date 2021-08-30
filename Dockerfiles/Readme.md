# Building Docker images for RISC-V


## Node-exporter

```sh
git clone https://github.com/prometheus/node_exporter
git checkout v1.2.0 # Check latest version

# Build binary
for arch in amd64 arm arm64 riscv64 ppc64le; do CGO_ENABLED=0 GOOS=linux GOARCH=$arch gob -o  node_exporter-$arch .; done

cat > Dockerfile.node-exporter <<- 'EOF'
FROM carlosedp/busybox:1.31
ARG TARGETARCH
LABEL maintainer="The Prometheus Authors <prometheus-developers@googlegroups.com>"

COPY node_exporter-$TARGETARCH /bin/node_exporter

EXPOSE      9100
USER        nobody
ENTRYPOINT  [ "/bin/node_exporter" ]
EOF

docker buildx build -t carlosedp/node-exporter:v1.2.0 --platform linux/amd64,linux/arm64,linux/ppc64le,linux/arm,linux/riscv64 --push -f Dockerfile.node-exporter .
```
