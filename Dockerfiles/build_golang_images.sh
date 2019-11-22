REPO=carlosedp
IMAGE=$REPO/golang
VERSION=1.13
ALL_ARCH='amd64 arm arm64 riscv64'
DOCKERHUB_ARCH='amd64 arm32v7 arm64v8 riscv64'

for arch in $ALL_ARCH; do
    docker pull $arch/golang:1.13-buster
    docker tag 
done

docker pull arm64v8/golang:1.13-buster
docker pull arm32v7/golang:1.13-buster
docker pull amd64/golang:1.13-buster
docker pull carlosedp/golang:1.13-riscv64

docker tag arm64v8/golang:1.13-buster     $IMAGE:$VERSION-arm64
docker tag arm32v7/golang:1.13-buster     $IMAGE:$VERSION-arm
docker tag amd64/golang:1.13-buster       $IMAGE:$VERSION-amd64
docker tag carlosedp/golang:1.13-riscv64  $IMAGE:$VERSION-riscv64

docker push $IMAGE:$VERSION-arm64
docker push $IMAGE:$VERSION-arm
docker push $IMAGE:$VERSION-amd64
docker push $IMAGE:$VERSION-riscv64

docker manifest create --amend $IMAGE:$VERSION `echo $ALL_ARCH | sed -e "s~[^ ]*~$IMAGE:$VERSION\-&~g"`

for arch in 'amd64 arm arm64 riscv64'; do docker manifest annotate --arch $arch $IMAGE:$VERSION $IMAGE:$VERSION-$arch; done
docker manifest push --purge $IMAGE:$VERSION

docker rmi $IMAGE:$VERSION-arm64
docker rmi $IMAGE:$VERSION-arm
docker rmi $IMAGE:$VERSION-amd64
docker rmi $IMAGE:$VERSION-riscv64
docker rmi arm64v8/golang:1.13-buster
docker rmi arm32v7/golang:1.13-buster
docker rmi amd64/golang:1.13-buster
docker rmi carlosedp/golang:1.13-riscv64
