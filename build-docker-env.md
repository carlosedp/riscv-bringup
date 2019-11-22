# Build requirements for Containers on Risc-V

This doc allows one to build and set the requirements to run containers on Risc-V architecture.

It has been tested on a SiFive Unleashed board.

Create a temporary place for building:

```
mkdir -p $HOME/riscv-docker
cd $HOME/riscv-docker
```

## Kernel seccomp support

## libseccomp

Libseccomp builds fine without Kernel support, just applying the PR https://github.com/seccomp/libseccomp/pull/134.

```bash
git clone git://github.com/seccomp/libseccomp
pushd libseccomp
git fetch origin pull/134/head:riscv64
git checkout riscv64
./autogen.sh
./configure
make
make install
popd
```

## crun

```bash
# Install pre-reqs
sudo apt install pkgconf libtool libsystemd-dev libcap-dev libyajl-dev libselinux1-dev go-md2man libtool
git clone https://github.com/giuseppe/crun
pushd crun
./autogen.sh
./configure
make
sudo cp crun /usr/local/bin
sudo ln -sf /usr/local/bin/crun /usr/local/bin/runc
popd
```

## containerd

```bash
mkdir -p $GOPATH/src/github.com/containerd/
pushd $GOPATH/src/github.com/containerd/
git clone https://github.com/containerd/containerd
pushd containerd

LASTVER=`git tag |grep -v beta |grep -v "\-rc" |tail -1`
git checkout $LASTVER

VERSION=`git describe --match 'v[0-9]*' --dirty='.m' --always`
REVISION=`git rev-parse HEAD; if ! git diff --no-ext-diff --quiet --exit-code; then echo .m; fi`
go build -ldflags "-X github.com/containerd/containerd/version.Version=$VERSION -X github.com/containerd/containerd/version.Revision=$REVISION -X github.com/containerd/containerd/version.Package=./cmd/ctr -s -w" ./cmd/ctr

go build -tags no_btrfs -ldflags "-X github.com/containerd/containerd/version.Version=$VERSION -X github.com/containerd/containerd/version.Revision=$REVISION -X github.com/containerd/containerd/version.Package=./cmd/containerd -s -w" ./cmd/containerd

go build -ldflags "-X github.com/containerd/containerd/version.Version=$VERSION -X github.com/containerd/containerd/version.Revision=$REVISION -X github.com/containerd/containerd/version.Package=./cmd/containerd-shim -extldflags "-static" -s -w" ./cmd/containerd-shim

sudo cp ctr containerd-shim containerd /usr/local/bin/
popd
popd
```

## docker-cli

```bash
mkdir -p $GOPATH/src/github.com/docker/
pushd $GOPATH/src/github.com/docker/
git clone https://github.com/docker/cli
pushd cli
./scripts/build/binary
sudo cp ./build/docker-linux-riscv64 /usr/local/bin
sudo ln -sf /usr/local/bin/docker-linux-riscv64 /usr/local/bin/docker
popd
popd
```

## dockerd

```bash
mkdir -p $GOPATH/src/github.com/docker/
pushd $GOPATH/src/github.com/docker/
git clone git://github.com/moby/moby docker
pushd docker

patch --ignore-whitespace << 'EOF'
diff --git a/hack/make.sh b/hack/make.sh
index 1bd37b02cd..49c5df6b0a 100755
--- a/hack/make.sh
+++ b/hack/make.sh
@@ -91,6 +91,10 @@ elif ${PKG_CONFIG} 'libsystemd-journal' 2> /dev/null ; then
        DOCKER_BUILDTAGS+=" journald journald_compat"
 fi

+if [ "$(uname -m)" = 'riscv64' ]; then
+    DOCKER_BUILDTAGS+=" exclude_disk_quota exclude_graphdriver_devicemapper"
+fi
+
 # test whether "libdevmapper.h" is new enough to support deferred remove
 # functionality. We favour libdm_dlsym_deferred_remove over
 # libdm_no_deferred_remove in dynamic cases because the binary could be shipped
diff --git a/hack/make/.binary b/hack/make/.binary
index 66f4ca05f3..0685828d8b 100644
--- a/hack/make/.binary
+++ b/hack/make/.binary
@@ -72,7 +72,7 @@ fi

 # -buildmode=pie is not supported on Windows and Linux on mips.
 case "$(go env GOOS)/$(go env GOARCH)" in
-       windows/*|linux/mips*)
+       windows/*|linux/mips*|linux/riscv*)
                ;;
        *)
                BUILDFLAGS+=( "-buildmode=pie" )
EOF

./hack/make.sh binary
go build -tags "exclude_disk_quota exclude_graphdriver_devicemapper" ./cmd/dockerd/
sudo cp bundles/binary-daemon/dockerd-dev /usr/local/bin
popd
popd
```

## docker-init

```bash
git clone https://github.com/krallin/tini
pushd tini
export CFLAGS="-DPR_SET_CHILD_SUBREAPER=36 -DPR_GET_CHILD_SUBREAPER=37"
cmake . && make
sudo cp tini-static /usr/local/bin/docker-init
popd
```

## docker-proxy

```bash
mkdir $GOPATH/src/github.com/docker
pushd docker
git clone https://github.com/docker/libnetwork/
pushd libnetwork
go get github.com/ishidawataru/sctp
go build ./cmd/proxy
sudo cp proxy /usr/local/bin/docker-proxy
popd
popd
```

Or run dockerd with: `sudo dockerd --userland-proxy=false`

--------------------------------------------------------------------------------

## Running

```bash
# Execute containerd
sudo containerd

# Execute dockerd
sudo dockerd #or with the proxy parameter

# Run docker client
sudo docker version
```

