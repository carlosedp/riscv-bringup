#!/bin/bash
REPO=carlosedp

mkdir -p $GOPATH/src/github.com/openfaas
mkdir -p $GOPATH/src/github.com/nats-io
pushd $GOPATH/src/github.com/openfaas

git clone https://github.com/openfaas/faas-cli
git clone https://github.com/openfaas/faas-swarm
git clone https://github.com/openfaas/faas-netes
git clone https://github.com/openfaas/faas
git clone https://github.com/openfaas/nats-queue-worker/
git clone https://github.com/openfaas-incubator/faas-idler

# Build faas-cli
pushd faas-cli
CGO_ENABLED=0 GOOS=linux go build --ldflags "-s -w" -a -installsuffix cgo -o faas-cli
sudo cp faas-cli /usr/local/bin
popd

# Build faas-gateway
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

mv Dockerfile Dockerfile-orig
cat <<EOF >>Dockerfile
FROM carlosedp/golang:1.13 as golang
ENV CGO_ENABLED=0

WORKDIR /go/src/github.com/openfaas/nats-queue-worker

COPY vendor     vendor
COPY handler    handler
COPY nats       nats
COPY main.go  .
COPY types.go .
COPY readconfig.go .
COPY readconfig_test.go .
COPY auth.go .

ARG go_opts

RUN env $go_opts CGO_ENABLED=0 go build -a -installsuffix cgo -o app . \
    && addgroup --system app \
    && adduser --system --ingroup app app \
    && apt-get update \
    && apt-get install -y ca-certificates \
    && mkdir /scratch-tmp

# we can't add user in next stage because it's from scratch
# ca-certificates and tmp folder are also missing in scratch
# so we add all of it here and copy files in next stage

FROM scratch

EXPOSE 8080
ENV http_proxy      ""
ENV https_proxy     ""
USER app

COPY --from=golang /etc/passwd /etc/group /etc/
COPY --from=golang /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=golang --chown=app:app /scratch-tmp /tmp
COPY --from=golang /go/src/github.com/openfaas/nats-queue-worker/app    .

CMD ["./app"]
EOF

make build-riscv64
docker tag openfaas/queue-worker:latest-riscv64 $REPO/faas-queue-worker:riscv64
docker rmi openfaas/queue-worker:latest-riscv64
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

# Build Faas-netes
pushd faas-netes
CGO_ENABLED=0 GOOS=linux go build --ldflags "-s -w" -a -installsuffix cgo -o faas-netes

cat <<EOF >>Dockerfile.riscv64
FROM carlosedp/debian:sid-riscv64

LABEL org.label-schema.license="MIT" \
      org.label-schema.vcs-url="https://github.com/openfaas/faas-netes" \
      org.label-schema.vcs-type="Git" \
      org.label-schema.name="openfaas/faas-netes" \
      org.label-schema.vendor="openfaas" \
      org.label-schema.docker.schema-version="1.0"

RUN addgroup --system app && \
    adduser --system app --ingroup app && \
    apt-get update && \
    apt-get install -y ca-certificates

WORKDIR /home/app

ADD faas-netes .
RUN chown -R app:app ./

EXPOSE 8080

ENV http_proxy      ""
ENV https_proxy     ""

USER app
CMD ["./faas-netes"]
EOF
docker build -t $REPO/faas-netes:riscv64 -f Dockerfile.riscv64 .
docker push $REPO/faas-netes:riscv64
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