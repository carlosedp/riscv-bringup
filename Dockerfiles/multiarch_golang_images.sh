#!/bin/bash
# exit on error
set -e

REPO=carlosedp
PROJECT=golang
VERSION=1.16.5
IMAGE=$REPO/$PROJECT
ALL_ARCH='amd64 arm arm64 riscv64 ppc64le'
DOCKERHUB_ARCH='amd64 arm32v7 arm64v8 riscv64 ppc64le'

DOCKER_BUILDKIT=0 docker buildx build --platform=linux/riscv64 -t $REPO/$PROJECT:$VERSION-riscv64 --build-arg=VERSION=$VERSION -f Dockerfile.$PROJECT --load .
docker push $REPO/$PROJECT:$VERSION-riscv64

docker pull arm64v8/$PROJECT:$VERSION-sid
docker pull arm32v7/$PROJECT:$VERSION-sid
docker pull amd64/$PROJECT:$VERSION-sid
docker pull ppc64le/$PROJECT:$VERSION-sid
docker pull $REPO/$PROJECT:$VERSION-riscv64

docker tag arm64v8/$PROJECT:$VERSION-sid     $IMAGE:$VERSION-arm64
docker tag arm32v7/$PROJECT:$VERSION-sid     $IMAGE:$VERSION-arm
docker tag amd64/$PROJECT:$VERSION-sid       $IMAGE:$VERSION-amd64
docker tag ppc64le/$PROJECT:$VERSION-sid     $IMAGE:$VERSION-ppc64le
docker tag $REPO/$PROJECT:$VERSION-riscv64      $IMAGE:$VERSION-riscv64

docker push $IMAGE:$VERSION-arm64
docker push $IMAGE:$VERSION-arm
docker push $IMAGE:$VERSION-amd64
docker push $IMAGE:$VERSION-ppc64le
docker push $IMAGE:$VERSION-riscv64

docker manifest create --amend $IMAGE:$VERSION `echo $ALL_ARCH | sed -e "s~[^ ]*~$IMAGE:$VERSION\-&~g"`

for arch in 'amd64 arm arm64 riscv64 ppc64le'; do docker manifest annotate --arch $arch $IMAGE:$VERSION $IMAGE:$VERSION-$arch; done
docker manifest push --purge $IMAGE:$VERSION

docker rmi $IMAGE:$VERSION-arm64
docker rmi $IMAGE:$VERSION-arm
docker rmi $IMAGE:$VERSION-amd64
docker rmi $IMAGE:$VERSION-ppc64le
docker rmi $IMAGE:$VERSION-riscv64
docker rmi arm64v8/$PROJECT:$VERSION-sid
docker rmi arm32v7/$PROJECT:$VERSION-sid
docker rmi amd64/$PROJECT:$VERSION-sid
docker rmi ppc64le/$PROJECT:$VERSION-sid
docker rmi $REPO/$PROJECT:$VERSION-riscv64
