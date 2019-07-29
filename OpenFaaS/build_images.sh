#!/bin/bash
REPO=carlosedp

mkdir -p $GOPATH/src/github.com/openfaas
mkdir -p $GOPATH/src/github.com/nats-io
pushd $GOPATH/src/github.com/openfaas

git clone https://github.com/openfaas/faas-cli
git clone https://github.com/openfaas/faas-swarm
git clone https://github.com/openfaas/faas
git clone https://github.com/openfaas/nats-queue-worker/

# Build faas-cli
pushd faas-cli
CGO_ENABLED=0 GOOS=linux go build --ldflags "-s -w" -a -installsuffix cgo -o faas-cli
sudo cp faas-cli /usr/local/bin
popd

pushd faas/gateway
CGO_ENABLED=0 GOOS=linux go build --ldflags "-s -w" -a -installsuffix cgo -o gateway

cat <<EOF >>Dockerfile.riscv64
FROM carlosedp/debian:sid-riscv64

ARG ARCH="riscv64"

LABEL org.label-schema.license="MIT" \
    org.label-schema.vcs-url="https://github.com/openfaas/faas" \
    org.label-schema.vcs-type="Git" \
    org.label-schema.name="openfaas/faas" \
    org.label-schema.vendor="openfaas" \
    org.label-schema.docker.schema-version="1.0"

RUN addgroup --system app \
    && adduser --system --ingroup app app \
    && apt-get update \
    && apt-get install -y ca-certificates

WORKDIR /home/app

EXPOSE 8080
EXPOSE 8082
ENV http_proxy      ""
ENV https_proxy     ""

COPY gateway  .
COPY assets  assets
RUN sed -ie s/x86_64/${ARCH}/g assets/script/funcstore.js && \
  rm assets/script/funcstore.jse

RUN chown -R app:app ./

USER app

CMD ["./gateway"]
EOF
docker build -t $REPO/faas-gateway:riscv64 -f Dockerfile.riscv64 .
docker push $REPO/faas-gateway:riscv64
popd

# Build Watchdog
pushd faas/watchdog
CGO_ENABLED=0 GOOS=linux go build --ldflags "-s -w" -a -installsuffix cgo -o watchdog
cat <<EOF >>Dockerfile.riscv64
FROM scratch

COPY watchdog ./fwatchdog
EOF
docker build -t $REPO/faas-watchdog:riscv64 -f Dockerfile.riscv64 .
docker push $REPO/faas-watchdog:riscv64
popd

# Build Basic-Auth
pushd faas/auth/basic-auth
CGO_ENABLED=0 GOOS=linux go build --ldflags "-s -w" -a -installsuffix cgo -o handler
cat <<EOF >>Dockerfile.riscv64
FROM carlosedp/debian:sid-riscv64

RUN addgroup --system app \
    && adduser --system --ingroup app app

WORKDIR /home/app

COPY handler  .

RUN chown -R app:app ./

USER app

CMD ["./handler"]
EOF
docker build -t $REPO/faas-basic-auth-plugin:riscv64 -f Dockerfile.riscv64 .
docker push $REPO/faas-basic-auth-plugin:riscv64
popd

# Build Nats-Queue-Worker
pushd nats-queue-worker
CGO_ENABLED=0 GOOS=linux go build --ldflags "-s -w" -a -installsuffix cgo -o app

cat <<EOF >>Dockerfile.riscv64
FROM carlosedp/debian:sid-riscv64
ARG ARCH="riscv64"

LABEL org.label-schema.license="MIT" \
    org.label-schema.vcs-url="https://github.com/openfaas/faas" \
    org.label-schema.vcs-type="Git" \
    org.label-schema.name="openfaas/faas" \
    org.label-schema.vendor="openfaas" \
    org.label-schema.docker.schema-version="1.0"

RUN addgroup --system app \
    && adduser --system --ingroup app app \
    && apt-get update \
    && apt-get install -y ca-certificates

WORKDIR /home/app

EXPOSE 8080
ENV http_proxy      ""
ENV https_proxy     ""

COPY app  .

RUN chown -R app:app ./

USER app

CMD ["./app]
EOF
docker build -t $REPO/faas-queue-worker:riscv64 -f Dockerfile.riscv64 .
docker push $REPO/faas-queue-worker:riscv64
popd

# Build Faas-Swarm
pushd faas-swarm
CGO_ENABLED=0 GOOS=linux go build --ldflags "-s -w" -a -installsuffix cgo -o fs

cat <<EOF >>Dockerfile.riscv64
FROM carlosedp/debian:sid-riscv64

LABEL org.label-schema.license="MIT" \
      org.label-schema.vcs-url="https://github.com/openfaas/faas-swarm" \
      org.label-schema.vcs-type="Git" \
      org.label-schema.name="openfaas/faas-swarm" \
      org.label-schema.vendor="openfaas" \
      org.label-schema.docker.schema-version="1.0"

RUN apt-get update && apt-get install -y ca-certificates

WORKDIR /root/

EXPOSE 8080

ENV http_proxy      ""
ENV https_proxy     ""

COPY fs ./faas-swarm

CMD ["./faas-swarm"]
EOF
docker build -t $REPO/faas-swarm:riscv64 -f Dockerfile.riscv64 .
docker push $REPO/faas-swarm:riscv64
popd

# Nats Streaming Server
pushd $GOPATH/src/github.com/nats-io
git clone https://github.com/nats-io/nats-streaming-server
pushd nats-streaming-server
CGO_ENABLED=0 GOOS=linux go build --ldflags "-s -w" -a -installsuffix cgo -o nats-streaming-server
cat <<EOF >>Dockerfile.riscv64
FROM scratch

COPY nats-streaming-server /nats-streaming-server

# Expose client and management ports
EXPOSE 4222 8222

# Run with default memory based store
ENTRYPOINT ["/nats-streaming-server"]
CMD ["-m", "8222"]
EOF

docker build -t $REPO/faas-nats-streaming:riscv64 -f Dockerfile.riscv64 .
docker push $REPO/faas-nats-streaming:riscv64
popd

popd