#!/bin/bash

ARCHITECTURES="amd64 arm64 arm ppc64le riscv64"
BASEIMAGE=carlosedp/debian:sid-slim
VERSION=`git describe | sed -E 's/(v[0-9]\.[0-9]*\.[0-9]*-[a-zA-Z0-9]*\.[0-9]*).*/\1/'`
REPO=carlosedp

export DOCKER_CLI_EXPERIMENTAL=enabled

# force Go 1.13
export PATH=/home/carlosedp/riscv-go/bin:$PATH

# Build Kubernetes binaries
pushd kubernetes

patch --dry-run --ignore-whitespace << 'EOF'
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

make KUBE_BUILD_PLATFORMS=linux/riscv64


make generated_files
for arch in $ARCHITECTURES; do
	for i in kubeadm kubelet kube-apiserver kube-proxy kube-scheduler kube-controller-manager kubemark;
	do
    echo "Building $i for $arch"
        make WHAT=./cmd/$i KUBE_BUILD_PLATFORMS=linux/riscv64
	done
done
popd

# Base image for kube-proxy and flannel
BASEIMAGE=carlosedp/debian-iptables:sid-slim
REPO=carlosedp
cat > Dockerfile <<- 'EOF'
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
docker buildx build -t ${REPO}/debian-iptables:sid-slim --platform linux/amd64,linux/arm64,linux/ppc64le,linux/arm,linux/riscv64 --build-arg=BASEIMAGE=$BASEIMAGE --push .

# Build images
for bin in kube-apiserver kube-scheduler kube-controller-manager; do
		cat > Dockerfile <<- 'EOF'
		ARG BASEIMAGE
		FROM $BASEIMAGE
		ARG TARGETARCH
		ARG BIN
        ENV arch $TARGETARCH
		COPY $BIN-$arch /usr/local/bin/$BIN
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
		ADD $BIN-$arch /usr/local/bin/$BIN
		EOF
	docker buildx build -t ${REPO}/${bin}:${VERSION} --platform linux/amd64,linux/arm64,linux/ppc64le,linux/arm,linux/riscv64 --build-arg=BASEIMAGE=$BASEIMAGE --build-arg=BIN=$bin --push .
done

# Build pause image
ARCHITECTURES="amd64 arm64 arm ppc64le riscv64"
ORIGINIMAGE=k8s.gcr.io/pause
IMAGE=carlosedp/pause
VERSION=3.1
# Build image for riscv and push as carlosedp/pause:3.1-riscv64
for arch in amd64 arm64 arm ppc64le; do
    docker pull $ORIGINIMAGE-$arch:$VERSION
    docker tag $ORIGINIMAGE-$arch:$VERSION $IMAGE:$VERSION-$arch
    docker push $IMAGE:$VERSION-$arch
done
docker manifest create --amend $IMAGE:$VERSION `echo $ARCHITECTURES | sed -e "s~[^ ]*~$IMAGE:$VERSION\-&~g"`
for arch in $ARCHITECTURES; do docker manifest annotate --arch $arch $IMAGE:$VERSION $IMAGE:$VERSION-$arch; done
docker manifest push --purge $IMAGE:$VERSION

# Build CoreDNS
cd coredns
for arch in amd64 arm arm64 riscv64 ppc64le; do CGO_ENABLED=0 GOOS=linux GOARCH=$arch gob -o coredns-$arch .; done

cp -R /etc/ssl/certs .
cat > Dockerfile.custom << 'EOF'
FROM scratch
ARG TARGETARCH
ENV arch=$TARGETARCH
COPY certs /etc/ssl/certs
ADD coredns-$arch /coredns

EXPOSE 53 53/udp
ENTRYPOINT ["/coredns"]
EOF
docker buildx build -t ${REPO}/coredns:1.6.2 --platform linux/amd64,linux/arm64,linux/ppc64le,linux/arm,linux/riscv64 --push -f Dockerfile.custom .

# Build Etcd

cd etcd
for arch in amd64 arm arm64 riscv64 ppc64le; do CGO_ENABLED=0 GOOS=linux GOARCH=$arch gob -o  etcd-$arch .; done
for arch in amd64 arm arm64 riscv64 ppc64le; do CGO_ENABLED=0 GOOS=linux GOARCH=$arch gob -o  etcdctl-$arch ./etcdctl; done

cp ../kubernetes/cluster/images/etcd/migrate-if-needed.sh .
cp -R ../kubernetes/cluster/images/etcd/migrate .
cat > Dockerfile << 'EOF'
FROM carlosedp/debian:sid-slim
ARG TARGETARCH
ENV arch=$TARGETARCH
ENV ETCD_UNSUPPORTED_ARCH=riscv64
EXPOSE 2379 2380 4001 7001
COPY etcd-$arch /usr/local/bin/etcd
COPY etcdctl-$arch /usr/local/bin/etcdctl
COPY migrate-if-needed.sh migrate /usr/local/bin/
EOF
docker buildx build -t ${REPO}/etcd:3.3.10 --platform linux/amd64,linux/arm64,linux/ppc64le,linux/arm,linux/riscv64 --push .

# Build Flannel
ARCHITECTURES="amd64 arm64 arm ppc64le riscv64"
ORIGINIMAGE=quay.io/coreos/flannel
IMAGE=carlosedp/flannel
VERSION=v0.11.0

cat > Dockerfile.riscv64 << EOF
FROM carlosedp/debian-iptables:sid-slim
LABEL maintainer="Carlos Eduardo <carlosedp@gmail.com>"
ENV FLANNEL_ARCH=riscv64
RUN apt-get update && apt-get install -y --no-install-recommends iproute2 net-tools ca-certificates iptables strongswan && update-ca-certificates
RUN apt-get install -y --no-install-recommends wireguard-tools
COPY dist/flanneld-$FLANNEL_ARCH /opt/bin/flanneld
COPY dist/mk-docker-opts.sh /opt/bin/
ENTRYPOINT ["/opt/bin/flanneld"]
EOF

# Build image for riscv and push as carlosedp/flannel:v0.11.0-riscv64
for arch in amd64 arm64 arm ppc64le; do
    docker pull $ORIGINIMAGE:$VERSION-$arch
    docker tag $ORIGINIMAGE:$VERSION-$arch $IMAGE:$VERSION-$arch
    docker push $IMAGE:$VERSION-$arch
    docker rmi $ORIGINIMAGE:$VERSION-$arch
done
docker manifest create --amend $IMAGE:$VERSION `echo $ARCHITECTURES | sed -e "s~[^ ]*~$IMAGE:$VERSION\-&~g"`
for arch in $ARCHITECTURES; do docker manifest annotate --arch $arch $IMAGE:$VERSION $IMAGE:$VERSION-$arch; done
docker manifest push --purge $IMAGE:$VERSION

