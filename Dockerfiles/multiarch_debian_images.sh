#!/bin/bash
# exit on error
set -e

REPO=carlosedp
# PROJECT=debian
PROJECT=$1
# VERSION=sid
VERSION=$2
IMAGE=$REPO/$PROJECT
ALL_ARCH=(amd64 arm arm64 riscv64 ppc64le)
ALL_ARCH_STR='amd64 arm arm64 riscv64 ppc64le'
DOCKERHUB_ARCH=(amd64 arm32v7 arm64v8 riscv64 ppc64le)

# docker pull arm64v8/$PROJECT:$VERSION
# docker pull arm32v7/$PROJECT:$VERSION
# docker pull amd64/$PROJECT:$VERSION
# docker pull ppc64le/$PROJECT:$VERSION
# docker pull $REPO/$PROJECT:$VERSION-riscv64

# docker tag arm64v8/$PROJECT:$VERSION         $IMAGE:$VERSION-arm64
# docker tag arm32v7/$PROJECT:$VERSION         $IMAGE:$VERSION-arm
# docker tag amd64/$PROJECT:$VERSION           $IMAGE:$VERSION-amd64
# docker tag ppc64le/$PROJECT:$VERSION         $IMAGE:$VERSION-ppc64le
# docker tag $REPO/$PROJECT:$VERSION-riscv64   $IMAGE:$VERSION-riscv64

# docker push $IMAGE:$VERSION-arm64
# docker push $IMAGE:$VERSION-arm
# docker push $IMAGE:$VERSION-amd64
# docker push $IMAGE:$VERSION-ppc64le
# docker push $IMAGE:$VERSION-riscv64

docker manifest create --amend $IMAGE:$VERSION `echo $ALL_ARCH_STR | sed -e "s~[^ ]*~$IMAGE:$VERSION\-&~g"`

for arch in $ALL_ARCH; do
    docker manifest annotate --arch $arch $IMAGE:$VERSION $IMAGE:$VERSION-$arch;
done

docker manifest push --purge $IMAGE:$VERSION

# docker rmi $IMAGE:$VERSION-arm64
# docker rmi $IMAGE:$VERSION-arm
# docker rmi $IMAGE:$VERSION-amd64
# docker rmi $IMAGE:$VERSION-ppc64le
# docker rmi $IMAGE:$VERSION-riscv64
# docker rmi arm64v8/$PROJECT:$VERSION
# docker rmi arm32v7/$PROJECT:$VERSION
# docker rmi amd64/$PROJECT:$VERSION
# docker rmi ppc64le/$PROJECT:$VERSION
# docker rmi $REPO/$PROJECT:$VERSION-riscv64
