# Risc-V bring-up tracker <!-- omit in toc -->

The objective of this repository is to track the progress and pre-requisites to allow containers and Go applications on Risc-V.

There is a companion article available on https://medium.com/@carlosedp/docker-containers-on-risc-v-architecture-5bc45725624b.

## Contents <!-- omit in toc -->

* [Virtual machine, pre-built Go and Docker](#virtual-machine-pre-built-go-and-docker)
* [Building Go on your Risc-V VM or SBC](#building-go-on-your-risc-v-vm-or-sbc)
* [Go Dependencies](#go-dependencies)
  * [Pending upstream](#pending-upstream)
  * [Upstreamed](#upstreamed)
* [Docker and pre-reqs](#docker-and-pre-reqs)
  * [Libseccomp (https://github.com/seccomp/libseccomp)](#libseccomp-httpsgithubcomseccomplibseccomp)
  * [Runc (https://github.com/opencontainers/runc)](#runc-httpsgithubcomopencontainersrunc)
  * [Crun (https://github.com/giuseppe/crun)](#crun-httpsgithubcomgiuseppecrun)
  * [Containerd (https://github.com/containerd/containerd/)](#containerd-httpsgithubcomcontainerdcontainerd)
  * [Docker](#docker)
    * [Docker cli (github.com/docker/cli)](#docker-cli-githubcomdockercli)
    * [Docker daemon](#docker-daemon)
    * [docker-init (https://github.com/krallin/tini)](#docker-init-httpsgithubcomkrallintini)
    * [docker-proxy](#docker-proxy)
* [Podman - libpod (https://github.com/containers/libpod)](#podman---libpod-httpsgithubcomcontainerslibpod)
* [Base Container Images](#base-container-images)
* [Additional projects / libraries](#additional-projects--libraries)
  * [OpenFaaS](#openfaas)
    * [faas-cli (https://github.com/openfaas/faas-cli/)](#faas-cli-httpsgithubcomopenfaasfaas-cli)
    * [FaaS (https://github.com/openfaas/faas/)](#faas-httpsgithubcomopenfaasfaas)
    * [nats-streaming-server (https://github.com/nats-io/nats-streaming-server)](#nats-streaming-server-httpsgithubcomnats-ionats-streaming-server)
    * [nats-queue-worker (https://github.com/openfaas/nats-queue-worker)](#nats-queue-worker-httpsgithubcomopenfaasnats-queue-worker)
    * [faas-swarm (https://github.com/openfaas/faas-swarm)](#faas-swarm-httpsgithubcomopenfaasfaas-swarm)
    * [Sample Functions](#sample-functions)
  * [bbolt (https://github.com/etcd-io/bbolt)](#bbolt-httpsgithubcometcd-iobbolt)
  * [Pty (https://github.com/kr/pty)](#pty-httpsgithubcomkrpty)
  * [ETCD](#etcd)
  * [Kubernetes](#kubernetes)
  * [Prometheus](#prometheus)
  * [Promu](#promu)
  * [SQlite](#sqlite)
  * [LXD](#lxd)
  * [Go-Jsonnet (https://github.com/google/go-jsonnet)](#go-jsonnet-httpsgithubcomgooglego-jsonnet)
  * [Github Hub tool (https://github.com/github/hub)](#github-hub-tool-httpsgithubcomgithubhub)
  * [Labstack Echo Framework (https://github.com/labstack/echo)](#labstack-echo-framework-httpsgithubcomlabstackecho)
    * [Labstack Gommon (https://github.com/labstack/gommon)](#labstack-gommon-httpsgithubcomlabstackgommon)
  * [VNDR (https://github.com/LK4D4/vndr)](#vndr-httpsgithubcomlk4d4vndr)
  * [Inlets (https://github.com/alexellis/inlets)](#inlets-httpsgithubcomalexellisinlets)
* [Community](#community)
* [References](#references)


## Virtual machine, pre-built Go and Docker

To make the development easier, there is a Qemu virtual machine based on Debian with some developer tools already installed.

The VM pack can be downloaded [here](https://drive.google.com/open?id=1O3dQouOqygnBtP5cZZ3uOghQO7hlrFhD) and there is a [readme for it](Qemu-VM.md).

To run Go on this VM, download the tarball from here and install with the commands:

```bash
# Copy the tarball to the VM
scp -P 22222 go-1.13dev-riscv.tar.gz root@localhost:

# In the VM, unpack (in root dir for example)
tar vxf go-1.13dev-riscv.tar.gz

# Link the files
rmdir /usr/local/go
ln -sf /root/riscv-go/ /usr/local/go

# Add to your PATH
export PATH="/usr/local/go/bin:$PATH"

# Addto bashrc
echo "export PATH=/usr/local/go/bin:$PATH" >> ~/.bashrc
```

To run Docker on your Risc-V environment, get the pack [here](https://drive.google.com/open?id=1Op8l6yq6H_C_zpZUpvO-zHxwbtcrAGcQ) and use the `install.sh` script.

To test it out after install, just run `docker run -d -p 8080:8080 carlosedp/echo_on_riscv` and then `curl http://localhost:8080`.

There is also a [Podman](https://podman.io) package. Check more info on [build-podman-env.md](build-podman-env.md).

## Building Go on your Risc-V VM or SBC

First checkout and bootstrap Go Risc-V tree into a host that has Go installed (could be Mac, Linux):

```bash
git clone https://github.com/4a6f656c/riscv-go
cd riscv-go/src
GOOS=linux GOARCH=riscv64 ./bootstrap.bash
# Copy the generated boostrap pack to the VM/SBC
scp -P 22222 ../../go-linux-riscv64-bootstrap.tbz root@localhost: # In case you use the VM provided above
```

Now on your Risc-V VM/SBC, clone the repository, export the path and bootstrap path you unpacked and build/test:

```bash
tar vxf go-linux-riscv64-bootstrap.tbz
git clone https://github.com/4a6f656c/riscv-go
cd riscv-go
export GOROOT_BOOTSTRAP=$HOME/go-linux-riscv64-bootstrap
export PATH="$(pwd)/misc/riscv:$(pwd)/bin:$PATH"
cd src
GOGC=off ./make.bash                            # Builds go on $HOME/riscv-go/bin that can be added to your path
GOGC=off  GO_TEST_TIMEOUT_SCALE=10 ./run.bash   # Tests the build
```

Now you can use this go build for testing/developing other projects.

--------------------------------------------------------------------------------

## Go Dependencies

### Pending upstream

* [ ] Go (https://github.com/golang/go/issues/27532 / https://github.com/4a6f656c/riscv-go)
* [ ] CGO implementation - Draft on https://github.com/carlosedp/riscv-go but far from complete/funtcional.
* [ ] Go Builder - https://go-review.googlesource.com/c/build/+/177918
* [ ] Qemu CAS bug - Patch works - http://lists.nongnu.org/archive/html/qemu-riscv/2019-05/msg00134.html

### Upstreamed

* [x] `golang.org/x/sys` (https://go-review.googlesource.com/c/sys/+/177799)
* [x] `golang.org/x/net` (https://go-review.googlesource.com/c/net/+/177997)
* [x] `golang.org/x/sys` - Add riscv64 to `endian_little.go` (https://github.com/golang/sys/pull/38)

--------------------------------------------------------------------------------

## Docker and pre-reqs

To build a complete container environment, check the [build-docker-env.md](build-docker-env.md) document.

### Libseccomp (https://github.com/seccomp/libseccomp)

Builds fine with PR 134 even without Kernel support.

* [ ] Depends on upstreaming Kernel support
  * [ ] https://patchwork.kernel.org/patch/10716119/
  * [ ] https://patchwork.kernel.org/patch/10716121/)
  * [ ] Also https://github.com/riscv/riscv-linux/commit/0712587b63964272397ed34864130912d2a87020
* [ ] PR - https://github.com/seccomp/libseccomp/pull/134
* [ ] Issue - https://github.com/seccomp/libseccomp/issues/110

### Runc (https://github.com/opencontainers/runc)

* [ ] Upstreamed / Works
* [ ] **CGO** (to build nsenter)
* [ ] Support `buildmode=pie`
* [ ] Add `riscv64` to `libcontainer/system/syscall_linux_64.go`
* [ ] After upstreaming, update `x/sys` and `x/net` modules
* [ ] libseccomp-dev
* [ ] apparmor - (`$ sudo aa-status -> apparmor module is not loaded.`)

### Crun (https://github.com/giuseppe/crun)

No changes required, builds fine even without Kernel support for seccomp. Depends on libseccomp.

* [x] Upstreamed / Works
* [ ] libseccomp

### Containerd (https://github.com/containerd/containerd/)

* [x] Upstreamed / Works
* [x] PR https://github.com/containerd/containerd/pull/3328

### Docker

#### Docker cli (github.com/docker/cli)

* [x] Upstreamed / Works
* [x] Update `x/sys` and `x/net` modules in `vendor`. [PR](https://github.com/docker/cli/pull/1926)

#### Docker daemon

* [x] Upstreamed / Works
* [x] PR https://github.com/moby/moby/pull/39423 - Update dependencies
* [x] PR https://github.com/moby/moby/pull/39327 - Remove CGO dependency
* [x] Update `x/sys` and `x/net` modules in `vendor`.
* [x] Update `etcd-io/bbolt` in `vendor`.
* [x] Update `github.com/vishvananda/netns` in `vendor`
* [x] Update `github.com/vishvananda/netlink` in `vendor`
* [x] Update `github.com/ishidawataru/sctp` in `vendor`
* [x] Update `github.com/docker/libnetwork` in `vendor`

Dependency lib PRs:

* [x] Upstreamed / Works
* [x] netns PR - https://github.com/vishvananda/netns/pull/34 or fork into moby as https://github.com/moby/moby/issues/39404
* [x] libnetwork PR - https://github.com/docker/libnetwork/pull/2389
* [x] libnetwork PR netns - https://github.com/docker/libnetwork/pull/2412

#### docker-init (https://github.com/krallin/tini)

No changes required. Just build and copy tini-static to /usr/local/bin/docker-init

* [x] Upstreamed / Works

#### docker-proxy

No changes required. https://github.com/docker/libnetwork/cmd/proxy

* [x] Upstreamed / Works

Alternative is run dockerd as: `sudo dockerd  --userland-proxy=false`

**Issues:**

* [ ] https://github.com/moby/moby/issues/39461 - Error on interactive terminal and log tail. When launching a container with `-it` the console is not presented. After killing the container, the inputs given are shown. Also log tailing with `logs -f` does not tail.
* [ ] https://github.com/containerd/containerd/issues/3389 - Containerd CPU 100% Issue

## Podman - libpod (https://github.com/containers/libpod)

* [x] PR to remove CGO dependency https://github.com/containers/libpod/pull/3437
* [x] PR for containers/storage - https://github.com/containers/storage/pull/375
* [x] PR for containers/psgo - https://github.com/containers/psgo/pull/53

**Issues:**

* [ ] CNI Issue - https://github.com/containers/libpod/issues/3462

## Base Container Images

* [ ] Debian (sid) -> `carlosedp/debian:sid-riscv64`
* [ ] Alpine -> No MUSL available
* [ ] Busybox (1.31.0) -> ``
* [ ] Go (1.13 dev) -> `carlosedp/golang:1.13-riscv64`

--------------------------------------------------------------------------------

## Additional projects / libraries

### OpenFaaS

#### faas-cli (https://github.com/openfaas/faas-cli/)

* [ ] Migrate to go modules
* [ ] Update `x/sys`
* [ ] PR -

#### FaaS (https://github.com/openfaas/faas/)

* [ ] Migrate to go modules
* [ ] Update `x/sys`
* [ ] PR -

**Images:**

* [x] gateway - carlosedp/faas-gateway:riscv64
* [x] faas-basic-auth-plugin - carlosedp/faas-basic-auth-plugin:riscv64
* [x] faas-swarm - carlosedp/faas-swarm:riscv64
* [x] nats-streaming - carlosedp/faas-nats-streaming:riscv64
* [x] queue-worker - carlosedp/faas-queue-worker:riscv64
* [x] watchdog - carlosedp/faas-watchdog:riscv64
* [x] Function base - carlosedp/faas-debianfunction:riscv64

#### nats-streaming-server (https://github.com/nats-io/nats-streaming-server)

* [ ] Migrate to go modules
* [ ] Update `x/sys`
* [ ] PR -

#### nats-queue-worker (https://github.com/openfaas/nats-queue-worker)

* [ ] Migrate to go modules
* [ ] Update `x/sys`
* [ ] PR -

#### faas-swarm (https://github.com/openfaas/faas-swarm)

* [x] Depends on `x/sys` PR https://github.com/golang/sys/pull/38
* [ ] Migrate to go modules
* [ ] Update `x/sys`
* [ ] PR - 

#### Sample Functions

* [x] Sample Function - Figlet - carlosedp/faas-figlet:riscv64

### bbolt (https://github.com/etcd-io/bbolt)

* [x] Upstreamed / Works
* [x] PR - https://github.com/etcd-io/bbolt/pull/159

### Pty (https://github.com/kr/pty)

* [x] Upstreamed / Works
* [x] `kr/pty` (https://github.com/kr/pty/pull/81)

### ETCD

* [ ] Upstreamed / Works
* [ ] PR https://github.com/etcd-io/etcd/pull/10834
* [x] `x/net`
* [x] `x/sys`
* [ ] Backport changes to release 3.2.x for Kubernetes?

### Kubernetes

Dependencies for **kubelet**:

* [ ] Upstreamed / Works
* [ ] `x/net`
* [ ] `x/sys`
* [ ] bbolt
* [ ] runc/libcontainers -> CGO
* [ ] cadvisor/accelerators/nvidia -> github.com/mindprince/gonvml depends on CGO
* [ ] ???

### Prometheus

Already builds successfully

* [ ] Upstreamed / Works
* [ ] PR https://github.com/prometheus/prometheus/pull/5621
* [x] After upstreaming, update `x/sys` and `x/net` modules - `GO111MODULE=on go get -u golang.org/x/net && go get golang.org/x/sys && go mod tidy`
* [x] Apply patch from https://github.com/carlosedp/prometheus/commit/19e7ec54724240cde9768384736ff6ab88b1ace2

### Promu

Already builds successfully

* [x] Upstreamed / Works
* [x] PR https://github.com/prometheus/promu/pull/146
* [x] After upstreaming, update `x/sys` and `x/net` modules - `GO111MODULE=on go get -u golang.org/x/net && go get golang.org/x/sys && go mod tidy`

### SQlite

Repository mirror: https://github.com/CanonicalLtd/sqlite

* [ ] Upstreamed / Works
* [ ] Update `config.guess` and `config.sub` to newer version. Posted to [mailing list](https://www.mail-archive.com/sqlite-users@mailinglists.sqlite.org/msg115489.html).

### LXD

* [ ] Upstreamed / Works
* [x] LXC build successfully
* [ ] SQLite `config` update to build successfully
* [ ] CGO to build storage backends

### Go-Jsonnet (https://github.com/google/go-jsonnet)

* [x] Upstreamed / Works
* [x] Update `x/sys`
* [x] PR https://github.com/google/go-jsonnet/pull/284

### Github Hub tool (https://github.com/github/hub)

* [x] Upstreamed / Works
* [x] Update `x/sys`
* [x] PR https://github.com/github/hub/pull/2153

### Labstack Echo Framework (https://github.com/labstack/echo)

* [x] Upstreamed / Works
* [x] Update `x/sys`
* [x] Update `x/net`
* [x] PR https://github.com/labstack/echo/pull/1344

#### Labstack Gommon (https://github.com/labstack/gommon)

* [x] Upstreamed / Works
* [x] Update `x/sys`
* [x] PR https://github.com/labstack/gommon/pull/32

### VNDR (https://github.com/LK4D4/vndr)

* [x] Upstreamed / Works
* [x] PR https://github.com/LK4D4/vndr/pull/80

### Inlets (https://github.com/alexellis/inlets)

* [ ] Upstreamed / Works
* [ ] PR https://github.com/alexellis/inlets/pull/70

--------------------------------------------------------------------------------

## Community

* Slack channel #risc-v on https://invite.slack.golangbridge.org

## References

* [RISC-V Assembly Programmer's Manual](https://github.com/riscv/riscv-asm-manual/blob/master/riscv-asm.md)
* [RISC-V ELF psABI specification](https://github.com/riscv/riscv-elf-psabi-doc/blob/master/riscv-elf.md)
