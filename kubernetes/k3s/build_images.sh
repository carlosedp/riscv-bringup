#!/bin/bash

set -xe

REPO=carlosedp
TMPPATH=$HOME

##############
# Build Images
##############

mkdir -p $HOME/k3s-images
pushd $HOME/k3s-images


####
## CoreDNS
####

git clone https://github.com/coredns/coredns
cd coredns
VER=v1.8.0
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

####
## klipper-helm
####

git clone https://github.com/rancher/klipper-helm
pushd klipper-helm
KLIPPERVERSION=v0.4.3
git checkout $KLIPPERVERSION

mkdir helm
git clone https://github.com/helm/helm
cd helm
git checkout v3.3.1
make build-cross

go get -u github.com/prometheus/procfs
go mod tidy && go mod vendor
GOFLAGS="-trimpath" GO111MODULE=on CGO_ENABLED=0 GOOS=linux GOARCH=riscv64 go build -ldflags '-w -s -X helm.sh/helm/v3/internal/version.metadata=unreleased -X helm.sh/helm/v3/internal/version.gitCommit=d55c53df4e394fb62b0514a09c57bce235dd7877 -X helm.sh/helm/v3/internal/version.gitTreeState=dirty -X helm.sh/helm/v3/pkg/lint/rules.k8sVersionMajor=1 -X helm.sh/helm/v3/pkg/lint/rules.k8sVersionMinor=20 -X helm.sh/helm/v3/pkg/chartutil.k8sVersionMajor=1 -X helm.sh/helm/v3/pkg/chartutil.k8sVersionMinor=20 -extldflags "-static"' -o _dist/linux-riscv64/helm ./cmd/helm
mv _dist _distv3
git reset --hard
mkdir $GOPATH/k8s.io/
cd ..
mv helm $GOPATH/k8s.io/
cd $GOPATH/k8s.io/helm
git checkout v2.16.10
GIT_COMMIT=$(git rev-parse "HEAD^{commit}" 2>/dev/null)
make bootstrap
# Replace sys mod to updated one on glide files.(47abb6519492c2e7f35c3a9f4d655f2bd32607cc)
for ARCH in amd64 arm64 arm ppc64le riscv64; do
    GO111MODULE=off GOOS=linux GOARCH=${ARCH} go build -tags '' -ldflags '-w -s -X k8s.io/helm/pkg/version.Version=v2.16.10 -X k8s.io/helm/pkg/version.BuildMetadata= -X k8s.io/helm/pkg/version.GitCommit=${GIT_COMMIT} -X k8s.io/helm/pkg/version.GitTreeState=dirty' -o _dist/linux-${ARCH}/helm ./cmd/helm
    GO111MODULE=off GOOS=linux GOARCH=${ARCH} go build -tags '' -ldflags '-w -s -X k8s.io/helm/pkg/version.Version=v2.16.10 -X k8s.io/helm/pkg/version.BuildMetadata= -X k8s.io/helm/pkg/version.GitCommit=${GIT_COMMIT} -X k8s.io/helm/pkg/version.GitTreeState=dirty' -o _dist/linux-${ARCH}/rudder ./cmd/rudder
    GO111MODULE=off GOOS=linux GOARCH=${ARCH} go build -tags '' -ldflags '-w -s -X k8s.io/helm/pkg/version.Version=v2.16.10 -X k8s.io/helm/pkg/version.BuildMetadata= -X k8s.io/helm/pkg/version.GitCommit=${GIT_COMMIT} -X k8s.io/helm/pkg/version.GitTreeState=dirty' -o _dist/linux-${ARCH}/tiller ./cmd/tiller
done

cd ..

cat > Dockerfile.custom << 'EOF'
FROM carlosedp/debian:sid

ARG TARGETARCH
ENV arch=$TARGETARCH

RUN apt-get update && \
    apt-get install -y ca-certificates jq bash git

COPY _distv3/linux-$arch/helm /usr/bin/helm_v3
COPY _distv2/linux-$arch/helm /usr/bin/helm_v2
COPY _distv2/linux-$arch/tiller /usr/bin/tiller
COPY entry /usr/bin/
ENV STABLE_REPO_URL=https://charts.helm.sh/stable/
ENTRYPOINT ["entry"]
EOF

docker buildx build --platform linux/arm64,linux/arm,linux/amd64,linux/ppc64le,linux/riscv64 -t $REPO/klipper-helm:$KLIPPERVERSION --push -f Dockerfile.custom .
popd

####
## klipper-lb
####

git clone https://github.com/rancher/klipper-lb
pushd klipper-lb
KLIPPERLBVERSION=v0.1.2
git checkout ${KLIPPERLBVERSION}

cat > Dockerfile.custom <<EOF
FROM carlosedp/debian-iptables:sid-slim
COPY entry /usr/bin/
CMD ["entry"]
EOF

docker buildx build --platform linux/arm64,linux/arm,linux/amd64,linux/ppc64le,linux/riscv64 -t $REPO/klipper-lb:$KLIPPERLBVERSION --push -f Dockerfile.custom .

popd

####
## metrics-server
####

git clone https://github.com/kubernetes-sigs/metrics-server
pushd metrics-server
#MSVERSION=`git tag | tail -1` # build last tagged version
MSVERSION=v0.3.6

GIT_COMMIT=$(git rev-parse "HEAD^{commit}" 2>/dev/null)
GIT_VERSION_RAW=$(git describe --tags --abbrev=14 "$GIT_COMMIT^{commit}" 2>/dev/null)
BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
for ARCH in amd64 arm64 arm ppc64le riscv64; do
    GOARCH=$ARCH GOOS=linux go build -ldflags '-w -X sigs.k8s.io/metrics-server/pkg/version.gitVersion=$GIT_VERSION_RAW -X sigs.k8s.io/metrics-server/pkg/version.gitCommit=$GIT_COMMIT -X sigs.k8s.io/metrics-server/pkg/version.buildDate=$BUILD_DATE' -o _output/$ARCH/metrics-server ./cmd/metrics-server;
done

cat > Dockerfile.simple <<EOF
FROM gcr.io/distroless/static:latest
ARG TARGETARCH

COPY _output/$TARGETARCH/metrics-server /metrics-server

ENTRYPOINT ["/metrics-server"]
EOF

docker buildx build --platform linux/arm64,linux/arm,linux/amd64,linux/ppc64le,linux/riscv64 -t $REPO/metrics-server:$MSVERSION --push -f Dockerfile.simple .
popd

####
## traefik 2
####
git clone https://github.com/containous/traefik.git
pushd traefik
TRAEFIKVERSION=v2.4.7
git checkout ${TRAEFIKVERSION}
make crossbinary-default

cat > Dockerfile.custom << 'EOF'
FROM scratch
ARG TARGETARCH
ENV arch=$TARGETARCH

COPY script/ca-certificates.crt /etc/ssl/certs/
COPY dist/traefik_linux-$arch /traefik

EXPOSE 80
ENTRYPOINT ["/traefik"]
EOF
mv .dockerignore dockerignore-dis
docker buildx build -t ${REPO}/traefik:${TRAEFIKVERSION} --platform linux/amd64,linux/arm64,linux/ppc64le,linux/arm,linux/riscv64 --push -f Dockerfile.custom .
mv dockerignore-dis .dockerignore

popd

####
## local-path-provisioner
####

git clone https://github.com/rancher/local-path-provisioner
pushd local-path-provisioner
LPPVERSION=v0.0.19
git checkout $LPPVERSION
LPPVERSION=v0.0.19
for ARCH in amd64 arm64 arm ppc64le riscv64;
do
    echo "Building local-path-provisioner version $LPPVERSION for $ARCH"
    CGO_ENABLED=0 GOOS=linux GOARCH=$ARCH go build -ldflags "-X main.VERSION=$LPPVERSION -extldflags -static -s -w" -o bin/local-path-provisioner-$ARCH;
done

cat > Dockerfile.simple <<EOF
FROM scratch
ARG TARGETARCH
COPY bin/local-path-provisioner-\$TARGETARCH /usr/bin/local-path-provisioner
CMD ["local-path-provisioner"]
EOF

docker buildx build --platform linux/arm64,linux/arm,linux/amd64,linux/ppc64le,linux/riscv64 -t $REPO/local-path-provisioner:$LPPVERSION --push -f Dockerfile.simple .
popd

####
## pause
####

# Build pause image
cd kubernetes
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

##############
# Finish
##############
popd


