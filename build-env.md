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
go build ./cmd/ctr
go build ./cmd/containerd-shim
go build -tags no_btrfs ./cmd/containerd
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
git clone git://github.com/tonistiigi/docker
pushd docker
git checkout 3de77084d559055e87414c2669b22091a8396990
go build -tags "no_quota_support exclude_graphdriver_devicemapper" ./cmd/dockerd/
#go build -tags "exclude_disk_quota exclude_graphdriver_devicemapper" ./cmd/dockerd/    # On new trees
sudo cp dockerd /usr/local/bin
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

