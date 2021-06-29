# RISC-V bring-up tracker <!-- omit in toc -->

The objective of this repository is to track the progress and pre-requisites to allow containers and Go applications on RISC-V.

The repo also hosts multiple files and images suited for the SiFive Unmatched and QEmu VMs.

There is a companion article available on <https://medium.com/@carlosedp/docker-containers-on-RISC-V-architecture-5bc45725624b>.

This page is also linked from [http://bit.ly/riscvtracker](http://bit.ly/riscvtracker).

If you like this project and others I've been contributing and would like to support me, please check-out my [Patreon page](https://patreon.com/carlosedp)!

## Contents <!-- omit in toc -->

* [RISC-V Unleashed SBC, Virtual Machines and pre-built binaries](#risc-v-unleashed-sbc-virtual-machines-and-pre-built-binaries)
* [Golang](#golang)
  * [Core Golang](#core-golang)
  * [Go Std Libraries](#go-std-libraries)
  * [External deps](#external-deps)
* [Docker and pre-reqs](#docker-and-pre-reqs)
  * [Libseccomp](#libseccomp)
  * [Runc](#runc)
  * [Crun](#crun)
  * [Containerd](#containerd)
  * [Docker](#docker)
    * [Docker cli](#docker-cli)
    * [Docker daemon](#docker-daemon)
    * [docker-init](#docker-init)
    * [docker-proxy](#docker-proxy)
  * [Issues](#issues)
* [Podman - libpod](#podman---libpod)
* [CNI Plugins](#cni-plugins)
  * [Issues](#issues-1)
* [Base Container Images](#base-container-images)
* [Docker images for projects](#docker-images-for-projects)
* [Kubernetes](#kubernetes)
* [K3s](#k3s)
* [Additional projects / libraries](#additional-projects--libraries)
  * [ETCD](#etcd)
  * [OpenFaaS](#openfaas)
    * [Faas-cli](#faas-cli)
    * [Faas-swarm](#faas-swarm)
    * [Nats-streaming-server](#nats-streaming-server)
    * [No changes required](#no-changes-required)
  * [Bbolt](#bbolt)
  * [Pty](#pty)
  * [Prometheus](#prometheus)
  * [Promu](#promu)
  * [AlertManager](#alertmanager)
  * [Traefik](#traefik)
  * [SQlite](#sqlite)
  * [Go-Jsonnet](#go-jsonnet)
  * [Github Hub tool](#github-hub-tool)
  * [Labstack Echo Framework](#labstack-echo-framework)
    * [Labstack Gommon](#labstack-gommon)
  * [VNDR](#vndr)
  * [Inlets](#inlets)
  * [Gin web framework](#gin-web-framework)
  * [go-isatty](#go-isatty)
  * [ginkgo](#ginkgo)
* [Community](#community)
* [References](#references)


## RISC-V Unleashed SBC, Virtual Machines and pre-built binaries

To make the development easier, there are Qemu virtual machines based on Debian and Ubuntu with some developer tools already installed.

For the SiFive Unmatched, there is a prebuilt SDcard image at [https://github.com/carlosedp/riscv-bringup/releases/download/v1.0/UbuntuHippo-RISC-V.img.gz](https://github.com/carlosedp/riscv-bringup/releases/download/v1.0/UbuntuHippo-RISC-V.img.gz)

For QEmu, there are three distributions of RISC-V pre-packaged VM images:

* [Debian Sid](https://github.com/carlosedp/riscv-bringup/releases/download/v1.0/debian-riscv64-QemuVM-202002.tar.gz)
* [Ubuntu Focal](https://github.com/carlosedp/riscv-bringup/releases/download/v1.0/UbuntuFocal-riscv64-QemuVM.tar.gz)

The user is `root` and password `riscv`. For more information, check [the readme](Qemu/Readme.md).

A prebuilt Go 1.16 tarball can be [downloaded here](https://github.com/carlosedp/riscv-bringup/releases/download/v1.0/go1.16.2-riscv64.tar.gz).

If required to build the complete boot stack composed of OpenSBI, U-Boot, Linux, checkout the guides for [SiFive Unmatched](unmatched/Readme.md), [SiFive Unleashed](unleashed/Readme.md) and [Qemu](Qemu/Readme.md).

To run Go on the VM or board, install with:

```bash
# Start the VM
./run_debian.sh

# Download Golang tarball
wget https://github.com/carlosedp/riscv-bringup/releases/download/v1.0/go1.16.2-riscv64.tar.gz

# In the VM, unpack (in root dir for example)
tar vxf go1.16.2-riscv64.tar.gz -C /usr/local/

# Add to your PATH
export PATH="/usr/local/go/bin:$PATH"

# Addto bashrc
echo "export PATH=/usr/local/go/bin:$PATH" >> ~/.bashrc
```

To run Docker on your RISC-V Debian or Ubuntu environment, download a [deb package](https://github.com/carlosedp/riscv-bringup/releases/download/v1.0/docker-v20.10.2-dev_riscv64.deb) and install with `sudo apt install ./docker-v20.10.2-dev_riscv64.deb`.

For other distros get the [tarball here](https://github.com/carlosedp/riscv-bringup/releases/download/v1.0/docker-v20.10.2-dev_riscv64.tar.gz) and unpack to your `/` dir. If the docker service doesn't start on install script, re-run `systemctl start docker`.

<details><summary>Docker-compose install instructions</summary></u>

```bash
# In Debian image
sudo apt-get install python3 python3-dev python3-pip

# For Fedora image
sudo dnf install python3-devel

sudo pip3 install docker-compose
```

</details>

To test it out after install, just run `docker run -d -p 8080:8080 carlosedp/echo-riscv` and then `curl http://localhost:8080`.

There are a couple of projects that build on RISC-V in my [go-playground](https://github.com/carlosedp/go-playground) repo.

There is also a [Podman](https://podman.io) package [here](https://github.com/carlosedp/riscv-bringup/releases/) in both `.deb` and `.tar.gz`. Check more info on [build-podman-env.md](build-podman-env.md) to build the package from scratch.

--------------------------------------------------------------------------------

## Golang

### Core Golang

Golang has been upstreamed as an experimental architecture in Go 1.14. There are no binaries published officially but the [releases](https://github.com/carlosedp/riscv-bringup/releases) section has the tarball.

To build Go from source, check [build-golang.md](build-golang.md).

* [x] Golang upstreaming
  * Tracker Issue: <https://github.com/golang/go/issues/27532>
  * Gerrit CLs: <https://go-review.googlesource.com/q/riscv+OR+riscv64>
  * RISC-V Fork: <https://github.com/4a6f656c/riscv-go>
* [ ] CGO implementation(fork) - <https://github.com/golang/go/issues/36641>

### Go Std Libraries

* [x] `golang.org/x/sys` - <https://go-review.googlesource.com/c/sys/+/177799>
* [x] `golang.org/x/net` - <https://go-review.googlesource.com/c/net/+/177997>
* [x] `golang.org/x/sys` - Add riscv64 to `endian_little.go` - <https://github.com/golang/sys/pull/38>

### External deps

* [x] Qemu atomic bug
  * Qemu patch - <http://lists.nongnu.org/archive/html/qemu-riscv/2019-05/msg00134.html>
  * Fix for Qemu in 4.1 - <https://wiki.qemu.org/ChangeLog/4.1#RISC-V>
  * Kernel Patch - <https://patchwork.kernel.org/patch/10997887/>

--------------------------------------------------------------------------------

## Docker and pre-reqs

To build a complete Docker container stack, check the [build-docker-env.md](build-docker-env.md) document.

Downloads for prebuilt packages are available on <https://github.com/carlosedp/riscv-bringup/releases>.

### Libseccomp

<https://github.com/seccomp/libseccomp>

Builds fine from master branch. Will be released with riscv64 support on 2.5.

* [x] Kernel support - <https://patchwork.kernel.org/project/linux-riscv/list/?series=164025>
  * Ref. <https://patchwork.kernel.org/patch/10716119/>
  * Ref. <https://patchwork.kernel.org/patch/10716121/>
  * Ref. <https://github.com/riscv/riscv-linux/commit/0712587b63964272397ed34864130912d2a87020>
* [ ] ~~PR - <https://github.com/seccomp/libseccomp/pull/134>~~
* [x] PR - <https://github.com/seccomp/libseccomp/pull/197>
* [x] Issue - <https://github.com/seccomp/libseccomp/issues/110>

### Runc

<https://github.com/opencontainers/runc>

* [ ] Upstreamed / Works
* [ ] Depends on **CGO** (to build nsenter)
* [ ] Support `buildmode=pie`
* [ ] Add `riscv64` to `libcontainer/system/syscall_linux_64.go`
* [ ] After upstreaming, update `x/sys` and `x/net` modules
* [ ] libseccomp-dev
* [ ] apparmor - (`$ sudo aa-status -> apparmor module is not loaded.`)
* [ ] Add to CI

### Crun

<https://github.com/giuseppe/crun>

No changes required, builds fine even without Kernel support for seccomp. Depends on libseccomp.

* [x] Upstreamed / Works
* [x] Rebuild with libseccomp
* [ ] Add to CI

### Containerd

<https://github.com/containerd/containerd/>

* [x] Upstreamed / Works
* [x] PR <https://github.com/containerd/containerd/pull/3328>
* [ ] Add to CI

### Docker

#### Docker cli

<https://github.com/docker/cli>

* [x] Upstreamed / Works (must be built from `master`)
* [x] Update `x/sys` and `x/net` modules in `vendor`. [PR](https://github.com/docker/cli/pull/1926)
* [x] Add riscv64 to manifest annotation. [PR#2084](https://github.com/docker/cli/pull/2084)
* [x] Add support for riscv64 on binfmt. [PR#21](https://github.com/docker/binfmt/pull/21)
* [x] Docker for Mac - Add RISC-V binfmt. [PR#4237](https://github.com/docker/for-mac/issues/4237)
* [ ] Add to CI

#### Docker daemon

<https://github.com/moby/moby>

* [x] Upstreamed / Works
* [x] PR <https://github.com/moby/moby/pull/40664> - Build scripts support for riscv64
* [x] PR <https://github.com/moby/moby/pull/39423> - Update dependencies
* [x] PR <https://github.com/moby/moby/pull/39327> - Remove CGO dependency
* [x] Update `x/sys` and `x/net` modules in `vendor`.
* [x] Update `etcd-io/bbolt` in `vendor`.
* [x] Update `github.com/vishvananda/netns` in `vendor`
* [x] Update `github.com/vishvananda/netlink` in `vendor`
* [x] Update `github.com/ishidawataru/sctp` in `vendor`
* [x] Update `github.com/docker/libnetwork` in `vendor`
* [ ] Add to CI

Dependency lib PRs:

* [x] Upstreamed / Works
* [x] netns PR - <https://github.com/vishvananda/netns/pull/34> or fork into moby as <https://github.com/moby/moby/issues/39404>
* [x] libnetwork PR - <https://github.com/docker/libnetwork/pull/2389>
* [x] libnetwork PR netns - <https://github.com/docker/libnetwork/pull/2412>

#### docker-init

<https://github.com/krallin/tini>

No changes required. Just build and copy tini-static to /usr/local/bin/docker-init

* [x] Upstreamed / Works

#### docker-proxy

No changes required. <https://github.com/docker/libnetwork/cmd/proxy>

* [x] Upstreamed / Works

Alternative is run dockerd as: `sudo dockerd  --userland-proxy=false`

### Issues

* [x] <https://github.com/moby/moby/issues/39461> - Error on interactive terminal and log tail. When launching a container with `-it` the console is not presented. After killing the container, the inputs given are shown. Also log tailing with `logs -f` does not tail.
  * [x] PR <https://github.com/moby/moby/pull/39726>
  * [x] PR <https://github.com/docker/cli/pull/2042>
* [x] <https://github.com/containerd/containerd/issues/3389> - Containerd CPU 100% Issue
  * Fixed by <https://github.com/golang/sys/pull/40> thru PR <https://github.com/containerd/containerd/pull/3526/>

--------------------------------------------------------------------------------

## Podman - libpod

<https://github.com/containers/libpod>

Podman is a library and tool for running OCI-based containers in Pods

* [x] PR to remove CGO dependency <https://github.com/containers/libpod/pull/3437>
* [x] PR for containers/storage - <https://github.com/containers/storage/pull/375>
* [x] PR for containers/psgo - <https://github.com/containers/psgo/pull/53>
* [ ] Add to CI

## CNI Plugins

<https://github.com/containernetworking/plugins>

* [x] Builds and runs.

### Issues

* [x] Podman CNI Issue - <https://github.com/containers/libpod/issues/3462>

--------------------------------------------------------------------------------

## Base Container Images

* Debian Sid (Multiarch) -> [`carlosedp/debian:sid`](https://hub.docker.com/r/carlosedp/debian)
* Debian Sid Slim (Multiarch) -> [`carlosedp/debian:sid-slim`](https://hub.docker.com/r/carlosedp/debian)
* Debian Sid iptables Slim (Multiarch) -> [`carlosedp/debian-iptables:sid-slim`](https://hub.docker.com/r/carlosedp/debian-iptables)
* Alpine -> No MUSL available yet
* Busybox (1.31.0) -> [`carlosedp/busybox:1.31`](https://hub.docker.com/r/carlosedp/busybox)
* Go 1.14 (Multiarch) -> [`carlosedp/golang:1.14`](https://hub.docker.com/r/carlosedp/golang)

## Docker images for projects

**OpenFaaS:**

* faas-gateway - [`carlosedp/faas-gateway:riscv64`](https://hub.docker.com/r/carlosedp/faas-gateway)
* faas-basic-auth-plugin - [`carlosedp/faas-basic-auth-plugin:riscv64`](https://hub.docker.com/r/carlosedp/faas-basic-auth-plugin)
* faas-swarm - [`carlosedp/faas-swarm:riscv64`](https://hub.docker.com/r/carlosedp/faas-swarm)
* faas-netes - [`carlosedp/faas-netes:riscv64`](https://hub.docker.com/r/carlosedp/faas-netes)
* nats-streaming - [`carlosedp/faas-nats-streaming:riscv64`](https://hub.docker.com/r/carlosedp/faas-nats-streaming)
* queue-worker - [`carlosedp/faas-queue-worker:riscv64`](https://hub.docker.com/r/carlosedp/faas-queue-worker)
* watchdog - [`carlosedp/faas-watchdog:riscv64`](https://hub.docker.com/r/carlosedp/faas-watchdog)
* Function base - [`carlosedp/faas-debianfunction:riscv64`](https://hub.docker.com/r/carlosedp/faas-debianfunction)
* Figlet - [`carlosedp/faas-figlet:riscv64`](https://hub.docker.com/r/carlosedp/faas-figlet)
* MarkdownRender - [`carlosedp/faas-markdownrender:riscv64`](https://hub.docker.com/r/carlosedp/faas-markdownrender)
* QRCode - [`carlosedp/faas-qrcode:riscv64`](https://hub.docker.com/r/carlosedp/faas-qrcode)

**Prometheus:**

* Prometheus - [`carlosedp/prometheus:v2.11.1-riscv64`](https://hub.docker.com/r/carlosedp/prometheus)
* AlertManager - [`carlosedp/alertmanager:v0.18.0-riscv64`](https://hub.docker.com/r/carlosedp/alertmanager)

**Traefik:**

* traefik v2 - [`carlosedp/traefik:v2.1-riscv64`](https://hub.docker.com/r/carlosedp/traefik)
* whoami - [`carlosedp/whoami:riscv64`](https://hub.docker.com/r/carlosedp/whoami)

**Kubernetes:**

* kube-apiserver - [`carlosedp/kube-apiserver:1.16.0`](https://hub.docker.com/r/carlosedp/kube-apiserver)
* kube-scheduler - [`carlosedp/kube-scheduler:1.16.0`](https://hub.docker.com/r/carlosedp/kube-scheduler)
* kube-controller-manager - [`carlosedp/kube-controller-manager:1.16.0`](https://hub.docker.com/r/carlosedp/kube-controller-manager)
* kube-proxy - [`carlosedp/kube-proxy:1.16.0`](https://hub.docker.com/r/carlosedp/kube-proxy)
* pause - [`carlosedp/pause:3.1`](https://hub.docker.com/r/carlosedp/pause)
* flannel - [`carlosedp/flannel:v0.11.0`](https://hub.docker.com/r/carlosedp/flannel)
* etcd (v3.5.0) - [`carlosedp/etcd:3.3.10`](https://hub.docker.com/r/carlosedp/etcd)
* CoreDNS (v1.6.3) - [`carlosedp/coredns:v1.6.2`](https://hub.docker.com/r/carlosedp/coredns)

Kubernetes images are multi-arch with manifests to `arm`, `arm64`, `amd64`, `riscv64` and `ppc64le`.
Some version mismatches due to Kubernetes hard-coded version check for CoreDNS and etcd.

**Misc Images:**

* Echo demo - [`carlosedp/echo-riscv`](https://hub.docker.com/r/carlosedp/echo-riscv)
* Whoami (Traefik demo) - [`carlosedp/whoami:riscv64`](https://hub.docker.com/r/carlosedp/echo-riscv)
* Kubernetes Pause - [`carlosedp/k8s-pause:riscv64`](https://hub.docker.com/r/carlosedp/k8s-pause)
* CoreDNS v1.3.0 - [`carlosedp/coredns:v1.3.0-riscv64`](https://hub.docker.com/r/carlosedp/coredns)

--------------------------------------------------------------------------------

## Kubernetes

<https://github.com/kubernetes/kubernetes/>

Building and deploying Kubernetes or K3s on RISC-V is detailed on a [dedicated readme](https://github.com/carlosedp/riscv-bringup/blob/master/kubernetes/Readme.md). There is a build script(`build_images.sh`) for custom images in `kubernetes` dir.

* [x] `github.com/mindprince/gonvml` - PR <https://github.com/mindprince/gonvml/pull/13> - Stub nocgo functions
* [x] `github.com/opencontainers/runc` - PR <https://github.com/opencontainers/runc/pull/2123> - Bump x/sys and support syscall.
* [x] `k8s.io/kubernetes/` - PR <https://github.com/kubernetes/kubernetes/pull/82342> - Bump `mindprince/gonvml` and change directives on `pkg/kubelet/cadvisor` files
* [x] `k8s.io/kubernetes/` - PR <https://github.com/kubernetes/kubernetes/pull/82349> - Bump `opencontainers/runc` and `x/sys` to support RISC-V
* [x] `k8s.io/kubernetes/` - PR <https://github.com/kubernetes/kubernetes/pull/86013> - Bump Ginkgo to support building on riscv64 arch
* [ ] `k8s.io/kubernetes/` - PR <https://github.com/kubernetes/kubernetes/pull/86011> - Add build support for riscv64 arch
* [x] `google/cadvisor` - PR <https://github.com/google/cadvisor/pull/2364> - Ignore CPU clock for riscv64

To Do:

* Cross-platform builder image. Update `kubernetes/build/build-image/cross` adding riscv64 toolchain. Depends on Ubuntu `crossbuild-essential-riscv64` be available.
* Add riscv64 to ./build/pause Makefile. Depends on Go image with RISC-V support and cross-platform image.

<details><summary>Updating dependencies</summary>

```bash
# Update dependency
./hack/pin-dependency.sh github.com/mindprince/gonvml
# Update vendor dir
./hack/update-vendor.sh

# Build all main binaries
make KUBE_BUILD_PLATFORMS=linux/riscv64

# Build specifiv binaries
make WHAT=./cmd/${bin} KUBE_BUILD_PLATFORMS=linux/riscv64

# Binaries will be placed on _output/local/go/bin/linux_riscv64/
```

</details>

## K3s

<https://github.com/rancher/k3s/>

K3s build depends on deploying external etcd database since sqlite embedded DB requires CGO. Another requirement is running k3s with Docker and crun as daemon (see Docker install) since runc, the default runtime for K3s requires CGO as well.

For more info, check file [kubernetes/Readme.md#K3s]

Bump:

* [x] <github.com/opencontainers/runc>
* [x] <github.com/rancher/kine>

* [x] `github.com/rancher/kine` - PR#14 - [Stub-out sqlite drivers to build Kine without CGO](https://github.com/rancher/kine/pull/14)
* [x] `github.com/rancher/kine` - PR#19 - [Update function signature on nocgo stub](https://github.com/rancher/kine/pull/19)
* [x] Bump `github.com/google/cadvisor` after merge
* [x] Bump `github.com/mindprince/gonvml`
* [x] Bump `github.com/rancher/kine` after merge
* [x] Bump `k8s.io/kubernetes` after merge
* [x] Bump `golang.org/x/sys`

<details><summary>Future</summary>

* Embed database
* Embed runtime

</details>

## Additional projects / libraries

### ETCD

<https://github.com/etcd-io/etcd>

Build with `go build .`, run with `ETCD_UNSUPPORTED_ARCH=riscv64 ./etcd`.

* [x] Upstreamed / Works
* [x] PR <https://github.com/etcd-io/etcd/pull/10834>
* [x] Bump `golang.org/x/net`
* [x] Bump `golang.org/x/sys`

### OpenFaaS

OpenFaaS is already upstreamed but still does not build images for RISC-V so I've built them and pushed to [my DockerHub](https://hub.docker.com/u/carlosedp) as links below. Here are the instructions to [deploy OpenFaaS](https://github.com/carlosedp/riscv-bringup/blob/master/OpenFaaS/Readme.md) on your RISC-V host or VM.

The PRs do not add functionality to cross-build the images for RISC-V yet since the base images still don't support the architecture. Check the [`build_images.sh`](OpenFaaS/build_images.sh) script to build the images manually.

#### Faas-cli

<https://github.com/openfaas/faas-cli/>

* [x] Update `x/sys`
* [x] PR - <https://github.com/openfaas/faas-cli/pull/667>
* [ ] Add to CI

#### Faas-swarm

<https://github.com/openfaas/faas-swarm>

* [x] Depends on `x/sys` PR <https://github.com/golang/sys/pull/38>
* [x] Update `x/sys`, `x/net`
* [x] PR - <https://github.com/openfaas/faas-swarm/pull/52>
* [ ] Add to CI

#### Nats-streaming-server

<https://github.com/nats-io/nats-streaming-server>

* [x] Bump `x/sys`, `etcd/bbolt`.
* [x] PR - <https://github.com/nats-io/nats-streaming-server/pull/891>
* [ ] Add to CI

#### No changes required

* FaaS - <https://github.com/openfaas/faas/>
* Nats-queue-worker - <https://github.com/openfaas/nats-queue-worker>
* Faas-netes - <https://github.com/openfaas/faas-netes>
* Faas-idler - <https://github.com/openfaas-incubator/faas-idler>

### Bbolt

<https://github.com/etcd-io/bbolt>

* [x] Upstreamed / Works
* [x] PR - <https://github.com/etcd-io/bbolt/pull/159>

### Pty

<https://github.com/kr/pty>

* [x] Upstreamed / Works
* [x] `kr/pty` (<https://github.com/kr/pty/pull/81)>

### Prometheus

<https://github.com/prometheus/prometheus>

Builds successfully with `make build`.

* [x] Upstreamed / Works
* [x] PR ~~<https://github.com/prometheus/prometheus/pull/5621>~~ -> <https://github.com/prometheus/prometheus/pull/5883>
* [x] Bump `x/sys` and `x/net` modules
* [x] Apply patch from <https://github.com/carlosedp/prometheus/commit/19e7ec54724240cde9768384736ff6ab88b1ace2>
* [ ] Add to CI

### Promu

<https://github.com/prometheus/promu>

* [x] Upstreamed / Works
* [x] PR <https://github.com/prometheus/promu/pull/146>
* [x] Bump `x/sys` and `x/net` modules
* [ ] Add to CI

### AlertManager

<https://github.com/prometheus/alertmanager>

Already builds successfully with `make build`.

* [x] Upstreamed / Works
* [x] PR <https://github.com/prometheus/alertmanager/pull/1984>

### Traefik

<https://github.com/containous/traefik>

* [x] Upstreamed / Works
* [x] PR <https://github.com/containous/traefik/pull/5245>

<details><summary>Building and running</summary>

```bash
rm -rf static/ autogen/
make generate-webui
go generate
mkdir dist
GOARCH=riscv64 GOOS=linux go build -o dist/traefik ./cmd/traefik
docker build -t carlosedp/traefik:v2.1-riscv64 .
```

To run an example stack with Docker Compose, create the file below and start it with `docker-compose up -d`. To test, you can open the address `http://[IP]:8080/dashboard` or `curl http://localhost:8080/api/rawdata`. Prometheus metrics are exposed on `http://localhost:8080/metrics`.

Create a `docker-compose.yml`

```yaml
version: '3'

services:
  reverse-proxy:
    # The official v2.0 Traefik docker image
    image: carlosedp/traefik:v2.0-riscv64
    # Enables the web UI and tells Traefik to listen to docker
    command: --api --providers.docker --metrics.prometheus=true
    ports:
      # The HTTP port
      - "80:80"
      # The Web UI (enabled by --api)
      - "8080:8080"
    volumes:
      # So that Traefik can listen to the Docker events
      - /var/run/docker.sock:/var/run/docker.sock
  whoami:
    # A container that exposes an API to show its IP address
    image: carlosedp/whoami:riscv64
    labels:
      - "traefik.http.routers.whoami.rule=Host(`whoami.docker.localhost`)"
```

Run with:

```bash
docker-compose up -d
```

</details>

### SQlite

SQLite builds on RISC-V but requires replacing its building files.

Repository mirror: <https://github.com/CanonicalLtd/sqlite>

* [ ] Upstreamed / Works
* [ ] Update `config.guess` and `config.sub` to newer version. Posted to [mailing list](https://www.mail-archive.com/sqlite-users@mailinglists.sqlite.org/msg115489.html).

### Go-Jsonnet

<https://github.com/google/go-jsonnet>

* [x] Upstreamed / Works
* [x] Update `x/sys`
* [x] PR <https://github.com/google/go-jsonnet/pull/284>

### Github Hub tool

<https://github.com/github/hub>

* [x] Upstreamed / Works
* [x] Update `x/sys`
* [x] PR <https://github.com/github/hub/pull/2153>

### Labstack Echo Framework

<https://github.com/labstack/echo>

* [x] Upstreamed / Works
* [x] Update `x/sys`
* [x] Update `x/net`
* [x] PR <https://github.com/labstack/echo/pull/1344>

#### Labstack Gommon

<https://github.com/labstack/gommon>

* [x] Upstreamed / Works
* [x] Update `x/sys`
* [x] PR <https://github.com/labstack/gommon/pull/32>

### VNDR

<https://github.com/LK4D4/vndr>

* [x] Upstreamed / Works
* [x] PR <https://github.com/LK4D4/vndr/pull/80>

### Inlets

<https://github.com/alexellis/inlets>

* [x] Upstreamed / Works
* [x] PR <https://github.com/alexellis/inlets/pull/78>
* [ ] Add to CI

### Gin web framework

<https://github.com/gin-gonic/gin>

* Depends on `github.com/mattn/go-isatty`.

* [x] Upstreamed / Works
* [x] PR <https://github.com/gin-gonic/gin/pull/2019>

### go-isatty

<https://github.com/mattn/go-isatty>

Dependency for Gin Framework

* [x] PR <https://github.com/mattn/go-isatty/pull/39>

### ginkgo

<https://github.com/onsi/ginkgo>

Dependency for building Kubernetes complete binaries

* [x] PR <https://github.com/onsi/ginkgo/pull/632>

--------------------------------------------------------------------------------

## Community

* Slack channel #RISC-V on <https://invite.slack.golangbridge.org>

## References

* [RISC-V Assembly Programmer's Manual](https://github.com/riscv/riscv-asm-manual/blob/master/riscv-asm.md)
* [RISC-V ELF psABI specification](https://github.com/riscv/riscv-elf-psabi-doc/blob/master/riscv-elf.md)
