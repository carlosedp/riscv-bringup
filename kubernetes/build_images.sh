#!/bin/bash
# This script requires docker cli built from master since released version does not support riscv64 manifest annotation

ARCHITECTURES=(amd64 arm64 arm ppc64le riscv64)
BASEIMAGE=carlosedp/debian:sid-slim
VERSION=`git describe | sed -E 's/(v[0-9]\.[0-9]*\.[0-9]*-[a-zA-Z0-9]*\.[0-9]*).*/\1/'`
REPO=carlosedp

export DOCKER_CLI_EXPERIMENTAL=enabled

# Build Kubernetes binaries
pushd kubernetes

patch -p1--ignore-whitespace << 'EOF'
diff --git a/hack/lib/golang.sh b/hack/lib/golang.sh
index ce7de73301..211580051e 100755
--- a/hack/lib/golang.sh
+++ b/hack/lib/golang.sh
@@ -27,6 +27,7 @@ readonly KUBE_SUPPORTED_SERVER_PLATFORMS=(
   linux/arm64
   linux/s390x
   linux/ppc64le
+  linux/riscv64
 )

 # The node platforms we build for
@@ -36,6 +37,7 @@ readonly KUBE_SUPPORTED_NODE_PLATFORMS=(
   linux/arm64
   linux/s390x
   linux/ppc64le
+  linux/riscv64
   windows/amd64
 )

@@ -48,6 +50,7 @@ readonly KUBE_SUPPORTED_CLIENT_PLATFORMS=(
   linux/arm64
   linux/s390x
   linux/ppc64le
+  linux/riscv64
   darwin/amd64
   darwin/386
   windows/amd64
@@ -62,6 +65,7 @@ readonly KUBE_SUPPORTED_TEST_PLATFORMS=(
   linux/arm64
   linux/s390x
   linux/ppc64le
+  linux/riscv64
   darwin/amd64
   windows/amd64
 )
EOF

for arch in $ARCHITECTURES; do
   #make cross KUBE_BUILD_PLATFORMS=linux/$arch
	for i in kubeadm kubelet kubectl kube-apiserver kube-proxy kube-scheduler kube-controller-manager kubemark;
	do
    echo "Building $i for $arch"
        make WHAT=./cmd/$i KUBE_BUILD_PLATFORMS=linux/$arch
	done
done
popd

# Base image for kube-proxy and flannel
BASEIMAGE=debian:sid-slim
REPO=carlosedp
cat > Dockerfile.debian-iptables <<- 'EOF'
ARG BASEIMAGE
FROM $BASEIMAGE
ARG TARGETARCH

RUN apt-get update && \
    apt-get install -y conntrack \
        ebtables \
        ipset \
        iptables \
        kmod \
        netbase
EOF
docker buildx build -t ${REPO}/debian-iptables:sid-slim --platform linux/amd64,linux/arm64,linux/ppc64le,linux/arm,linux/riscv64 --build-arg=BASEIMAGE=$BASEIMAGE --push -f Dockerfile.debian-iptables .

# Build images
for bin in kube-apiserver kube-scheduler kube-controller-manager; do
		cat > Dockerfile <<- 'EOF'
		ARG BASEIMAGE
		FROM $BASEIMAGE
		ARG TARGETARCH
		ARG BIN
        ENV arch $TARGETARCH
		COPY _output/local/go/bin/linux_${arch}/$BIN /usr/local/bin/$BIN
		EOF
    docker buildx build -t ${REPO}/${bin}:${VERSION} --platform linux/amd64,linux/arm64,linux/ppc64le,linux/arm,linux/riscv64 --build-arg=BASEIMAGE=$BASEIMAGE --build-arg=BIN=$bin --push .
done

# Build images for kube-proxy
BASEIMAGE=carlosedp/debian-iptables:sid-slim
for bin in kube-proxy; do
		cat > Dockerfile <<- 'EOF'
		ARG BASEIMAGE
		FROM $BASEIMAGE
		ARG TARGETARCH
		ARG BIN
		ENV arch $TARGETARCH
		ADD _output/local/bin/linux/$arch/$BIN /usr/local/bin/$BIN
		EOF
	docker buildx build -t ${REPO}/${bin}:${VERSION} --platform linux/amd64,linux/arm64,linux/ppc64le,linux/arm,linux/riscv64 --build-arg=BASEIMAGE=$BASEIMAGE --build-arg=BIN=$bin --push .
done

# Build pause image
TAG=3.2
docker run -it --rm -v $(PWD):/src -e TAG=${TAG} -w /src carlosedp/crossbuild-riscv64
cd build/pause
REV=`git describe --contains --always --match='v*'`
riscv64-linux-gcc -Os -Wall -Werror -static -DVERSION=v${TAG}-${REV} -o bin/pause-riscv64 linux/pause.c
exit
pushd build/pause
docker build -t ${REPO}/pause:${TAG}-riscv64 --build-arg=ARCH=riscv64 --build-arg=BASE=scratch -f Dockerfile .
docker push ${REPO}/pause:${TAG}-riscv64
popd
popd

ARCHITECTURES=(amd64 arm64 arm ppc64le riscv64)
ORIGINIMAGE=gcr.io/google-containers/pause
IMAGE=carlosedp/pause
VERSION=3.2
# Build image for riscv and push as carlosedp/pause:3.1-riscv64
for arch in amd64 arm64 arm ppc64le; do
    docker pull $ORIGINIMAGE-$arch:$VERSION
    docker tag $ORIGINIMAGE-$arch:$VERSION $IMAGE:$VERSION-$arch
    docker push $IMAGE:$VERSION-$arch
done
docker manifest create --amend $IMAGE:$VERSION `echo $ARCHITECTURES | sed -e "s~[^ ]*~$IMAGE:$VERSION\-&~g"`
for arch in $ARCHITECTURES; do docker manifest annotate --arch $arch $IMAGE:$VERSION $IMAGE:$VERSION-$arch; done
docker manifest push --purge $IMAGE:$VERSION
cd ..

# Build CoreDNS
git clone https://github.com/coredns/coredns
cd coredns
VER=v1.7.0
git checkout ${VER}
GITCOMMIT=`git describe --dirty --always`
for arch in amd64 arm arm64 riscv64 ppc64le; do CGO_ENABLED=0 GOOS=linux GOARCH=$arch go build -v -ldflags="-s -w -X github.com/coredns/coredns/coremain.GitCommit=${GITCOMMIT}" -o coredns-$arch .; done

docker run -it --rm -v $(PWD):/src -w /src carlosedp/crossbuild-riscv64 bash -c "cp -R /etc/ssl/certs . && cp -R /usr/share/ca-certificates/mozilla/ ./mozilla"
cat > Dockerfile.custom << 'EOF'
FROM scratch
ARG TARGETARCH
ENV arch=$TARGETARCH
ADD certs /etc/ssl/certs
ADD mozilla /usr/share/ca-certificates/mozilla
ADD coredns-$arch /coredns

EXPOSE 53 53/udp
ENTRYPOINT ["/coredns"]
EOF
mv .dockerignore dockerignore-dis
docker buildx build -t ${REPO}/coredns:${VER} --platform linux/amd64,linux/arm64,linux/ppc64le,linux/arm,linux/riscv64 --push -f Dockerfile.custom .
mv dockerignore-dis .dockerignore
cd ..

# Build Etcd
git clone https://github.com/etcd-io/etcd
VER=3.4.13
cd etcd
git checkout v${VER}
for arch in amd64 arm arm64 riscv64 ppc64le; do CGO_ENABLED=0 GOOS=linux GOARCH=$arch gob -o  etcd-$arch .; done
for arch in amd64 arm arm64 riscv64 ppc64le; do CGO_ENABLED=0 GOOS=linux GOARCH=$arch gob -o  etcdctl-$arch ./etcdctl; done

cp ../kubernetes/cluster/images/etcd/migrate-if-needed.sh .
cp -R ../kubernetes/cluster/images/etcd/migrate .
cat > Dockerfile << 'EOF'
FROM carlosedp/debian:sid-slim
ARG TARGETARCH
ENV arch=$TARGETARCH
ENV ETCD_UNSUPPORTED_ARCH=riscv64
COPY etcd-$arch /usr/local/bin/etcd
COPY etcdctl-$arch /usr/local/bin/etcdctl
COPY migrate-if-needed.sh migrate /usr/local/bin/
RUN mkdir -p /var/etcd/
RUN mkdir -p /var/lib/etcd/
RUN echo 'hosts: files mdns4_minimal [NOTFOUND=return] dns mdns4' >> /etc/nsswitch.conf
EXPOSE 2379 2380
CMD ["/usr/local/bin/etcd"]
EOF
docker buildx build -t ${REPO}/etcd:${VER} --platform linux/amd64,linux/arm64,linux/ppc64le,linux/arm,linux/riscv64 --push .
cd ..

# Build Flannel
IMAGE=carlosedp/flannel
VERSION=v0.14.0

cat > Dockerfile.flannel << 'EOF'
# Build with:
# docker buildx build -t $IMAGE:v0.14.0 --platform linux/amd64,linux/arm,linux/arm64,linux/ppc64le,linux/riscv64 --build-arg=VERSION=v0.14.0 -f Dockerfile.flannel --push .
#
FROM --platform=$BUILDPLATFORM golang:1.16 as builder
ARG VERSION
ARG TARGETOS
ARG TARGETARCH

ENV SRCREPO https://github.com/flannel-io/flannel
ENV TARGETDIR /go/src/github.com/flannel-io
ENV BINARY_NAME flanneld

RUN mkdir -p $TARGETDIR && \
    cd $TARGETDIR && \
    git clone $SRCREPO --depth 1 -b $VERSION

RUN cd $TARGETDIR/flannel && \
   make dist/flanneld && \
   mv dist/flanneld .

FROM carlosedp/debian-iptables:sid-slim
ARG VERSION
ARG TARGETOS
ARG TARGETARCH
LABEL maintainer="Carlos Eduardo <carlosedp@gmail.com>"
ENV FLANNEL_ARCH=$TARGETARCH
RUN apt-get update && apt-get install -y --no-install-recommends iproute2 net-tools ca-certificates iptables strongswan && update-ca-certificates
RUN apt-get install -y --no-install-recommends wireguard-tools
COPY --from=builder /go/src/github.com/flannel-io/flannel/flanneld /opt/bin/flanneld
COPY --from=builder /go/src/github.com/flannel-io/flannel/dist/mk-docker-opts.sh /opt/bin/
COPY --from=builder /go/src/github.com/flannel-io/flannel/dist/iptables-wrapper-installer.sh /
RUN /iptables-wrapper-installer.sh --no-sanity-check
ENTRYPOINT ["/opt/bin/flanneld"]
EOF

docker buildx build -t $IMAGE:v0.14.0 --platform linux/amd64,linux/arm,linux/arm64,linux/ppc64le,linux/riscv64 --build-arg=VERSION=v0.14.0 -f Dockerfile.flannel --push .

