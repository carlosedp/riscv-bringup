# Risc-V bring-up tracker <!-- omit in toc -->

The objective of this repository is to track the progress and pre-requisites to allow containers and Go applications on Risc-V.

There is a companion article available on https://medium.com/@carlosedp/docker-containers-on-risc-v-architecture-5bc45725624b.

This page is also linked from [http://bit.ly/riscvtracker](http://bit.ly/riscvtracker).

## Contents <!-- omit in toc -->

* [Risc-V Virtual Machine, pre-built Go and Docker](#risc-v-virtual-machine-pre-built-go-and-docker)
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
  * [Issues](#issues)
* [Podman - libpod (https://github.com/containers/libpod)](#podman---libpod-httpsgithubcomcontainerslibpod)
  * [Issues](#issues-1)
* [Base Container Images](#base-container-images)
* [Additional projects / libraries](#additional-projects--libraries)
  * [OpenFaaS](#openfaas)
    * [Faas-cli (https://github.com/openfaas/faas-cli/)](#faas-cli-httpsgithubcomopenfaasfaas-cli)
    * [Faas-swarm (https://github.com/openfaas/faas-swarm)](#faas-swarm-httpsgithubcomopenfaasfaas-swarm)
    * [FaaS (https://github.com/openfaas/faas/)](#faas-httpsgithubcomopenfaasfaas)
    * [Nats-streaming-server (https://github.com/nats-io/nats-streaming-server)](#nats-streaming-server-httpsgithubcomnats-ionats-streaming-server)
    * [Nats-queue-worker (https://github.com/openfaas/nats-queue-worker)](#nats-queue-worker-httpsgithubcomopenfaasnats-queue-worker)
    * [Sample Functions](#sample-functions)
  * [Bbolt (https://github.com/etcd-io/bbolt)](#bbolt-httpsgithubcometcd-iobbolt)
  * [Pty (https://github.com/kr/pty)](#pty-httpsgithubcomkrpty)
  * [ETCD](#etcd)
  * [Kubernetes](#kubernetes)
  * [Prometheus (https://github.com/prometheus/prometheus/)](#prometheus-httpsgithubcomprometheusprometheus)
  * [Promu (https://github.com/prometheus/promu/)](#promu-httpsgithubcomprometheuspromu)
  * [AlertManager (https://github.com/prometheus/alertmanager/)](#alertmanager-httpsgithubcomprometheusalertmanager)
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


## Risc-V Virtual Machine, pre-built Go and Docker

To make the development easier, there is a Qemu virtual machine based on Debian with developer tools already installed.

The VM pack can be downloaded [here](https://drive.google.com/open?id=1O3dQouOqygnBtP5cZZ3uOghQO7hlrFhD). For more information, check [the readme](Qemu-VM.md).

The prebuilt Go 1.13 tarball can be [downloaded here](https://drive.google.com/open?id=1jG23DjOkVpFxF00HPuAN8SmGEpaf8iAr).

To run Go on this VM, download both files and install with:

<details><summary>Instructions</summary></u>

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

</details>

To run Docker on your Risc-V environment, get the pack [here](https://drive.google.com/open?id=1Op8l6yq6H_C_zpZUpvO-zHxwbtcrAGcQ) and use the `install.sh` script.

To test it out after install, just run `docker run -d -p 8080:8080 carlosedp/echo_on_riscv` and then `curl http://localhost:8080`.

There is also a [Podman](https://podman.io) package. Check more info on [build-podman-env.md](build-podman-env.md).

## Building Go on your Risc-V VM or SBC

Golang is still not upstreamed so to build it from source, you will need a machine to do the initial bootstrap, copy this bootstraped tree to your Risc-V host or VM and then build the complete Go distribution. This bootstrap host can be a Windows, Mac or Linux.

<details><summary>Instructions</summary>

```bash
# On bootstrap Host
git clone https://github.com/4a6f656c/riscv-go
cd riscv-go/src
GOOS=linux GOARCH=riscv64 ./bootstrap.bash
# Copy the generated boostrap pack to the VM/SBC
scp -P 22222 ../../go-linux-riscv64-bootstrap.tbz root@localhost: # In case you use the VM provided above
```

Now on your Risc-V VM/SBC, clone the repository, export the path and bootstrap path you unpacked and build/test:

```bash
# On Risc-V Host
tar vxf go-linux-riscv64-bootstrap.tbz
git clone https://github.com/4a6f656c/riscv-go
cd riscv-go
export GOROOT_BOOTSTRAP=$HOME/go-linux-riscv64-bootstrap
export PATH="$(pwd)/misc/riscv:$(pwd)/bin:$PATH"
cd src
GOGC=off ./make.bash                            # Builds go on $HOME/riscv-go/bin that can be added to your path
GOGC=off  GO_TEST_TIMEOUT_SCALE=10 ./run.bash   # Tests the build
```

</details>

Now you can use this go build for testing/developing other projects.

--------------------------------------------------------------------------------

## Go Dependencies

### Pending upstream

* [ ] Go
  * Tracker Issue:https://github.com/golang/go/issues/27532
  * Risc-V Fork: https://github.com/4a6f656c/riscv-go
* [ ] CGO implementation - Draft on https://github.com/carlosedp/riscv-go but far from complete/funtcional.
* [ ] Go Builder
  * https://go-review.googlesource.com/c/build/+/188501
  * https://github.com/golang/build/pull/22
  * Based on https://go-review.googlesource.com/c/build/+/177918
* [ ] Qemu atomic bug
  * Qemu patch - http://lists.nongnu.org/archive/html/qemu-riscv/2019-05/msg00134.html
  * Fix for Qemu in 4.1 - https://wiki.qemu.org/ChangeLog/4.1#RISC-V
  * Kernel Patch - https://patchwork.kernel.org/patch/10997887/

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
* [ ] Add to CI

### Crun (https://github.com/giuseppe/crun)

No changes required, builds fine even without Kernel support for seccomp. Depends on libseccomp.

* [x] Upstreamed / Works
* [ ] libseccomp
* [ ] Add to CI

### Containerd (https://github.com/containerd/containerd/)

* [x] Upstreamed / Works
* [x] PR https://github.com/containerd/containerd/pull/3328
* [ ] Add to CI

### Docker

#### Docker cli (github.com/docker/cli)

* [x] Upstreamed / Works
* [x] Update `x/sys` and `x/net` modules in `vendor`. [PR](https://github.com/docker/cli/pull/1926)
* [ ] Add to CI

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
* [ ] Add to CI

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

### Issues

* [ ] https://github.com/moby/moby/issues/39461 - Error on interactive terminal and log tail. When launching a container with `-it` the console is not presented. After killing the container, the inputs given are shown. Also log tailing with `logs -f` does not tail.
* [ ] https://github.com/containerd/containerd/issues/3389 - Containerd CPU 100% Issue

## Podman - libpod (https://github.com/containers/libpod)

* [x] PR to remove CGO dependency https://github.com/containers/libpod/pull/3437
* [x] PR for containers/storage - https://github.com/containers/storage/pull/375
* [x] PR for containers/psgo - https://github.com/containers/psgo/pull/53
* [ ] Add to CI

### Issues

* [ ] CNI Issue - https://github.com/containers/libpod/issues/3462

## Base Container Images

* [ ] Debian (sid) -> [`carlosedp/debian:sid-riscv64`](https://cloud.docker.com/u/carlosedp/repository/docker/carlosedp/debian)
* [ ] Alpine -> No MUSL available
* [ ] Busybox (1.31.0) -> ``
* [ ] Go (1.13 dev) -> [`carlosedp/golang:1.13-riscv64`](https://cloud.docker.com/u/carlosedp/repository/docker/carlosedp/golang)

--------------------------------------------------------------------------------

## Additional projects / libraries

### OpenFaaS

OpenFaaS is already upstreamed but still does not build images for Risc-V so I've built them and pushed to [my DockerHub](https://cloud.docker.com/u/carlosedp) as links below. Here are the instructions to [deploy OpenFaaS](https://github.com/carlosedp/riscv-bringup/blob/master/OpenFaaS/Readme.md) on your Risc-V host or VM.

The PRs do not add functionality to cross-build the images for Risc-V yet since the base images still don't support the architecture. Check the [`build_images.sh`](OpenFaaS/build_images.sh) script to build the images manually.

**Images:**

* [x] gateway - [`carlosedp/faas-gateway:riscv64`](https://cloud.docker.com/u/carlosedp/repository/docker/carlosedp/faas-gateway)
* [x] faas-basic-auth-plugin - [`carlosedp/faas-basic-auth-plugin:riscv64`](https://cloud.docker.com/u/carlosedp/repository/docker/carlosedp/carlosedp/faas-basic-auth-plugin)
* [x] faas-swarm - [`carlosedp/faas-swarm:riscv64`](https://cloud.docker.com/u/carlosedp/repository/docker/carlosedp/carlosedp/faas-swarm)
* [x] nats-streaming - [`carlosedp/faas-nats-streaming:riscv64`](https://cloud.docker.com/u/carlosedp/repository/docker/carlosedp/carlosedp/faas-nats-streaming)
* [x] queue-worker - [`carlosedp/faas-queue-worker:riscv64`](https://cloud.docker.com/u/carlosedp/repository/docker/carlosedp/carlosedp/faas-queue-worker)
* [x] watchdog - [`carlosedp/faas-watchdog:riscv64`](https://cloud.docker.com/u/carlosedp/repository/docker/carlosedp/carlosedp/faas-watchdog)
* [x] Function base - [`carlosedp/faas-debianfunction:riscv64`](https://cloud.docker.com/u/carlosedp/repository/docker/carlosedp/carlosedp/faas-debianfunction)

#### Faas-cli (https://github.com/openfaas/faas-cli/)

* [x] Update `x/sys`
* [x] PR - https://github.com/openfaas/faas-cli/pull/667
* [ ] Add to CI

#### Faas-swarm (https://github.com/openfaas/faas-swarm)

* [x] Depends on `x/sys` PR https://github.com/golang/sys/pull/38
* [x] Update `x/sys`, `x/net`
* [x] PR - https://github.com/openfaas/faas-swarm/pull/52
* [ ] Add to CI

#### FaaS (https://github.com/openfaas/faas/)

No changes required.

* [ ] Add to CI

#### Nats-streaming-server (https://github.com/nats-io/nats-streaming-server)

* [x] Update `x/sys`, `etcd/bbolt`.
* [x] PR - https://github.com/nats-io/nats-streaming-server/pull/891
* [ ] Add to CI

#### Nats-queue-worker (https://github.com/openfaas/nats-queue-worker)

No changes required.

* [ ] Add to CI

#### Sample Functions

* [x] Figlet - [`carlosedp/faas-figlet:riscv64`](https://cloud.docker.com/u/carlosedp/repository/docker/carlosedp/faas-figlet)
* [x] MarkdownRender - [`carlosedp/faas-markdownrender:riscv64`](https://cloud.docker.com/u/carlosedp/repository/docker/carlosedp/faas-markdownrender)
* [x] QRCode - [`carlosedp/faas-qrcode:riscv64`](https://cloud.docker.com/u/carlosedp/repository/docker/carlosedp/faas-qrcode)

### Bbolt (https://github.com/etcd-io/bbolt)

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

### Prometheus (https://github.com/prometheus/prometheus/)

Already builds successfully with `make build` after updating modules.

* [ ] Upstreamed / Works
* [ ] PR https://github.com/prometheus/prometheus/pull/5621
* [x] After upstreaming, update `x/sys` and `x/net` modules - `GO111MODULE=on go get -u golang.org/x/net && go get -u golang.org/x/sys && go mod tidy`
* [x] Apply patch from https://github.com/carlosedp/prometheus/commit/19e7ec54724240cde9768384736ff6ab88b1ace2
* [ ] Add to CI

### Promu (https://github.com/prometheus/promu/)

Already builds successfully.

* [x] Upstreamed / Works
* [x] PR https://github.com/prometheus/promu/pull/146
* [x] After upstreaming, update `x/sys` and `x/net` modules - `GO111MODULE=on go get -u golang.org/x/net && go get golang.org/x/sys && go mod tidy`
* [ ] Add to CI

### AlertManager (https://github.com/prometheus/alertmanager/)

Already builds successfully with `make build`.

* [ ] Upstreamed / Works
* [ ] PR https://github.com/prometheus/alertmanager/pull/1984


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
* [ ] PR https://github.com/alexellis/inlets/pull/78
* [ ] Add to CI

--------------------------------------------------------------------------------

## Community

* Slack channel #risc-v on https://invite.slack.golangbridge.org

## References

* [RISC-V Assembly Programmer's Manual](https://github.com/riscv/riscv-asm-manual/blob/master/riscv-asm.md)
* [RISC-V ELF psABI specification](https://github.com/riscv/riscv-elf-psabi-doc/blob/master/riscv-elf.md)
