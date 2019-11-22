# Risc-V bring-up tracker <!-- omit in toc -->

The objective of this repository is to track the progress and pre-requisites to allow containers and Go applications on Risc-V.

There is a companion article available on <https://medium.com/@carlosedp/docker-containers-on-risc-v-architecture-5bc45725624b>.

This page is also linked from [http://bit.ly/riscvtracker](http://bit.ly/riscvtracker).

If you like this project and others I've been contributing and would like to support me, please check-out my [Patreon page](https://patreon.com/carlosedp)!

## Contents <!-- omit in toc -->

* [Risc-V Virtual Machine, pre-built Go and Docker](#risc-v-virtual-machine-pre-built-go-and-docker)
* [Building Go on your Risc-V VM or SBC](#building-go-on-your-risc-v-vm-or-sbc)
* [Go Dependencies](#go-dependencies)
  * [Core Golang](#core-golang)
  * [Go Libraries](#go-libraries)
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
* [Additional projects / libraries](#additional-projects--libraries)
  * [Kubernetes / K3s](#kubernetes--k3s)
    * [Kubernetes](#kubernetes)
    * [K3s](#k3s)
  * [ETCD](#etcd)
  * [OpenFaaS](#openfaas)
    * [Faas-cli](#faas-cli)
    * [Faas-swarm](#faas-swarm)
    * [Nats-streaming-server](#nats-streaming-server)
    * [Nats-streaming-server](#nats-streaming-server-1)
    * [No changes required](#no-changes-required)
  * [Bbolt](#bbolt)
  * [Pty](#pty)
  * [Prometheus](#prometheus)
  * [Promu](#promu)
  * [AlertManager](#alertmanager)
  * [Traefik](#traefik)
  * [SQlite](#sqlite)
  * [LXD](#lxd)
  * [Go-Jsonnet](#go-jsonnet)
  * [Github Hub tool](#github-hub-tool)
  * [Labstack Echo Framework](#labstack-echo-framework)
    * [Labstack Gommon](#labstack-gommon)
  * [VNDR](#vndr)
  * [Inlets](#inlets)
  * [Gin web framework](#gin-web-framework)
  * [go-isatty](#go-isatty)
* [Community](#community)
* [References](#references)


## Risc-V Virtual Machine, pre-built Go and Docker

To make the development easier, there are Qemu virtual machines based on Debian and Fedora with some developer tools already installed.

Download the [Risc-V Debian VM](https://drive.google.com/open?id=1O3dQouOqygnBtP5cZZ3uOghQO7hlrFhD). or [Risc-V Fedora VM](https://drive.google.com/open?id=1MndnrABt3LUgEBVq-ZYWWzo1PVhxfOla). For more information, check [the readme](Qemu-VM.md).

A prebuilt Go 1.13 tarball can be [downloaded here](https://drive.google.com/open?id=1jG23DjOkVpFxF00HPuAN8SmGEpaf8iAr).

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

To run Docker on your Risc-V Debian environment, download a [deb package](https://github.com/carlosedp/riscv-bringup/releases/download/v1.0/docker-19.03.5-dev_riscv64.deb) or for other distros get the [tarball here](https://drive.google.com/open?id=1x1ndaLTsUq6P5yHdOM4fzH4NO2xqOZlP) and use the `install.sh` script. If the docker service doesn't start on install script, re-run `systemctl start docker`.

<details><summary>Docker-compose instructions</summary></u>

```bash
# In Debian image
sudo apt-get install python3-dev

# In Fedora image
sudo dnf install python3-devel

sudo pip install docker-compose
```

</details>

To test it out after install, just run `docker run -d -p 8080:8080 carlosedp/echo-riscv` and then `curl http://localhost:8080`.

There are a couple of projects that build on Risc-V in my [go-playground](https://github.com/carlosedp/go-playground) repo.

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
# Pack built Golang into a tarball
cd ..
sudo tar -cvf go-1.13dev-riscv.tar --transform s/^riscv-go/go/ --exclude=pkg/obj --exclude .git riscv-go
```

</details>

Now you can use this go build for testing/developing other projects.

--------------------------------------------------------------------------------

## Go Dependencies

### Core Golang

* [ ] Golang
  * Tracker Issue: <https://github.com/golang/go/issues/27532>
  * Risc-V Fork: <https://github.com/4a6f656c/riscv-go>
* [ ] CGO implementation - Draft on <https://github.com/carlosedp/riscv-go> but far from complete/funtcional.
* [ ] Go Builder
  * <https://go-review.googlesource.com/c/build/+/188501>
  * <https://github.com/golang/build/pull/22>
  * Based on <https://go-review.googlesource.com/c/build/+/177918>

### Go Libraries

* [x] `golang.org/x/sys` - <https://go-review.googlesource.com/c/sys/+/177799>
* [x] `golang.org/x/net` - <https://go-review.googlesource.com/c/net/+/177997>
* [x] `golang.org/x/sys` - Add riscv64 to `endian_little.go` - <https://github.com/golang/sys/pull/38>

### External deps

* [ ] Qemu atomic bug
  * Qemu patch - <http://lists.nongnu.org/archive/html/qemu-riscv/2019-05/msg00134.html>
  * Fix for Qemu in 4.1 - <https://wiki.qemu.org/ChangeLog/4.1#RISC-V>
  * Kernel Patch - <https://patchwork.kernel.org/patch/10997887/>

--------------------------------------------------------------------------------

## Docker and pre-reqs

To build a complete container environment, check the [build-docker-env.md](build-docker-env.md) document.

### Libseccomp

<https://github.com/seccomp/libseccomp>

Builds fine with PR 134 even without Kernel support.

* [ ] Kernel support - <https://patchwork.kernel.org/project/linux-riscv/list/?series=164025>
  * Ref. <https://patchwork.kernel.org/patch/10716119/>
  * Ref. <https://patchwork.kernel.org/patch/10716121/>
  * Ref. <https://github.com/riscv/riscv-linux/commit/0712587b63964272397ed34864130912d2a87020>
* [ ] PR - <https://github.com/seccomp/libseccomp/pull/134>
* [ ] Issue - <https://github.com/seccomp/libseccomp/issues/110>

### Runc

<https://github.com/opencontainers/runc>

* [ ] Upstreamed / Works
* [ ] **CGO** (to build nsenter)
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
* [ ] Rebuild with libseccomp
* [ ] Add to CI

### Containerd

<https://github.com/containerd/containerd/>

* [x] Upstreamed / Works
* [x] PR <https://github.com/containerd/containerd/pull/3328>
* [ ] Add to CI

### Docker

#### Docker cli

<https://github.com/docker/cli>

* [x] Upstreamed / Works
* [x] Update `x/sys` and `x/net` modules in `vendor`. [PR](https://github.com/docker/cli/pull/1926)
* [x] Add riscv64 to manifest annotation. [PR#2084](https://github.com/docker/cli/pull/2084)
* [ ] Add to CI

#### Docker daemon

<https://github.com/moby/moby>

* [x] Upstreamed / Works
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
* Go 1.13 (Multiarch) -> [`carlosedp/golang:1.13`](https://hub.docker.com/r/carlosedp/golang)

## Docker images for projects

**OpenFaaS:**

* gateway - [`carlosedp/faas-gateway:riscv64`](https://hub.docker.com/r/carlosedp/faas-gateway)
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

* traefik v2 - [`carlosedp/traefik:v2.0-riscv64`](https://hub.docker.com/r/carlosedp/traefik)
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

## Additional projects / libraries

### Kubernetes / K3s

Building and deploying Kubernetes or K3s on Risc-V is detailed on a [dedicated readme](https://github.com/carlosedp/riscv-bringup/blob/master/kubernetes/Readme.md).

#### Kubernetes

<https://github.com/kubernetes/kubernetes/>

* [x] `github.com/mindprince/gonvml` - PR <https://github.com/mindprince/gonvml/pull/13> - Stub nocgo functions
* [x] `github.com/opencontainers/runc` - PR <https://github.com/opencontainers/runc/pull/2123> - Bump x/sys and support syscall.
* [x] `k8s.io/kubernetes/` - PR <https://github.com/kubernetes/kubernetes/pull/82342> - Bump `mindprince/gonvml` and change directives on `pkg/kubelet/cadvisor` files
* [ ] `k8s.io/kubernetes/` - PR <https://github.com/kubernetes/kubernetes/pull/82349> - Bump `opencontainers/runc` and `x/sys` to support Risc-V

<details><summary>Update process:</summary>

```bash
# Update dependency
./hack/pin-dependency.sh github.com/mindprince/gonvml
# Update vendor dir
./hack/update-vendor

# Generate API files
make generated_files

GOOS=linux GOARCH=riscv64 go build ./cmd/kube-apiserver
```

</details>

#### K3s

<https://github.com/rancher/k3s/>

* [ ] `github.com/ibuildthecloud/kvsql` - - Add stubs with no SQLite
* [ ] `github.com/rancher/kine` - - Add stubs with no SQLite

<details><summary>WIP</summary>

* [ ] Update imports on `pkg/server/context.go`
  * "k8s.io/kubernetes/staging/src/k8s.io/client-go/kubernetes" to "k8s.io/client-go/kubernetes"
  * "k8s.io/kubernetes/staging/src/k8s.io/client-go/tools/clientcmd" to "k8s.io/client-go/tools/clientcmd"
* [ ] Update imports on `pkg/cli/server/server.go` to load sqlite stubs
* [ ] Bump `github.com/google/cadvisor` after merge
* [ ] Bump `github.com/ibuildthecloud/kvsql` after merge
* [ ] Bump `github.com/mindprince/gonvml`
* [ ] Bump `github.com/opencontainers/runc` after merge
* [ ] Bump `github.com/rancher/kine` after merge
* [ ] Bump `k8s.io/kubernetes` after merge
* [ ] Bump `golang.org/x/sys`
* [ ] Add `k8s.io/utils/inotify/`

Files

Change `pkg/server/context.go` to build with Go 1.13:

```diff
diff --git a/pkg/server/context.go b/pkg/server/context.go
index 4f33b9aaca..9c65f19e36 100644
--- a/pkg/server/context.go
+++ b/pkg/server/context.go
@@ -12,9 +12,9 @@ import (
        "github.com/rancher/wrangler/pkg/apply"
        "github.com/rancher/wrangler/pkg/crd"
        "github.com/rancher/wrangler/pkg/start"
+       "k8s.io/client-go/kubernetes"
        "k8s.io/client-go/rest"
-       "k8s.io/kubernetes/staging/src/k8s.io/client-go/kubernetes"
-       "k8s.io/kubernetes/staging/src/k8s.io/client-go/tools/clientcmd"
+       "k8s.io/client-go/tools/clientcmd"
 )
```


File `vendor/github.com/google/cadvisor/container/containerd/client.go`:

Change import to `"github.com/containerd/containerd/pkg/dialer"`.

Files:

`vendor/k8s.io/kubernetes/pkg/kubelet/cadvisor/cadvisor_linux.go`
`vendor/k8s.io/kubernetes/pkg/kubelet/cadvisor/cadvisor_unsupported.go`
`vendor/k8s.io/kubernetes/pkg/kubelet/cadvisor/helpers_linux.go`
`vendor/k8s.io/kubernetes/pkg/kubelet/cadvisor/helpers_unsupported.go`

Change build directives (cgo).


Create sqlite stubs:

pkg/cli/server/server.go

vendor/github.com/ibuildthecloud/kvsql/clientv3/driver/sqlite/sqlite.go
vendor/github.com/ibuildthecloud/kvsql/clientv3/kv.go

vendor/github.com/rancher/kine/pkg/drivers/sqlite/sqlite.go
vendor/github.com/rancher/kine/pkg/endpoint/endpoint.go

</details>

### ETCD

<https://github.com/etcd-io/etcd>

Build with `go build .`, run with `ETCD_UNSUPPORTED_ARCH=riscv64 ./etcd`.

* [x] Upstreamed / Works
* [x] PR <https://github.com/etcd-io/etcd/pull/10834>
* [x] Bump `golang.org/x/net`
* [x] Bump `golang.org/x/sys`
* [ ] Backport changes to release 3.2.x for Kubernetes?

### OpenFaaS

OpenFaaS is already upstreamed but still does not build images for Risc-V so I've built them and pushed to [my DockerHub](https://hub.docker.com/u/carlosedp) as links below. Here are the instructions to [deploy OpenFaaS](https://github.com/carlosedp/riscv-bringup/blob/master/OpenFaaS/Readme.md) on your Risc-V host or VM.

The PRs do not add functionality to cross-build the images for Risc-V yet since the base images still don't support the architecture. Check the [`build_images.sh`](OpenFaaS/build_images.sh) script to build the images manually.

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

#### Nats-streaming-server

<https://github.com/nats-io/nats-streaming-server>

* [x] Update `x/sys`, `etcd/bbolt`.
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

<details><summary>Building</summary>

```bash
rm -rf static/ autogen/
make generate-webui
go generate
mkdir dist
GOARCH=riscv64 GOOS=linux go build -o dist/traefik ./cmd/traefik
docker build -t carlosedp/traefik:v2.1-riscv64 .
```

</details>

To run an example stack with Docker Compose, create the file below and start it with `docker-compose up -d`. To test, you can open the address `http://[IP]:8080/dashboard` or `curl http://localhost:8080/api/rawdata`. Prometheus metrics are exposed on `http://localhost:8080/metrics`.

<details><summary>docker-compose.yml</summary>

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

</details>

### SQlite

Repository mirror: <https://github.com/CanonicalLtd/sqlite>

* [ ] Upstreamed / Works
* [ ] Update `config.guess` and `config.sub` to newer version. Posted to [mailing list](https://www.mail-archive.com/sqlite-users@mailinglists.sqlite.org/msg115489.html).

### LXD

* [ ] Upstreamed / Works
* [x] LXC build successfully
* [ ] SQLite `config` update to build successfully
* [ ] CGO to build storage backends

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

--------------------------------------------------------------------------------

## Community

* Slack channel #risc-v on <https://invite.slack.golangbridge.org>

## References

* [RISC-V Assembly Programmer's Manual](https://github.com/riscv/riscv-asm-manual/blob/master/riscv-asm.md)
* [RISC-V ELF psABI specification](https://github.com/riscv/riscv-elf-psabi-doc/blob/master/riscv-elf.md)
