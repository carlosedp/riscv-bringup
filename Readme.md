# Risc-V bring-up tracker

The objective of this repository is to track the progress and pre-requisites to allow containers and Go applications on Risc-V.

## Virtual machine and pre-built Docker

To make the development easier, there is a Qemu virtual machine based on Debian with some developer tools already installed.

The pack can be downloaded [here](https://drive.google.com/open?id=1O3dQouOqygnBtP5cZZ3uOghQO7hlrFhD) and there is a [readme for it](Qemu-VM.md).

If you want to run Docker on your Risc-V environment, get the pack [here](https://drive.google.com/open?id=1Op8l6yq6H_C_zpZUpvO-zHxwbtcrAGcQ) and use the `install.sh` script.

To test it out after install, just run `docker run -d -p 8080:8080 carlosedp/echo_on_riscv` and then `curl http://localhost:8080`.

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

## Main dependencies

### Pending upstream

* [ ] Go (https://github.com/golang/go/issues/27532 / https://github.com/4a6f656c/riscv-go)
* [ ] CGO implementation - Draft on https://github.com/carlosedp/riscv-go but far from complete/funtcional.
* [ ] Go Builder - https://go-review.googlesource.com/c/build/+/177918
* [ ] Qemu CAS bug - Patch works - http://lists.nongnu.org/archive/html/qemu-riscv/2019-05/msg00134.html

### PR submitted

* [ ] `kr/pty` (https://github.com/kr/pty/pull/81)

### Already upstreamed

* [x] `golang.org/x/sys` (https://go-review.googlesource.com/c/sys/+/177799)
* [x] `golang.org/x/net` (https://go-review.googlesource.com/c/net/+/177997)
* [x] `etcd-io/bbolt`

--------------------------------------------------------------------------------

## Docker containers and pre-reqs

To build a complete container environment, check the [build-env.md](build-env.md) document.

### Libseccomp

Builds fine with PR 134 even without Kernel support.

* [ ] Depends on upstreaming Kernel support (https://patchwork.kernel.org/patch/10716119/ and https://patchwork.kernel.org/patch/10716121/). Also https://github.com/riscv/riscv-linux/commit/0712587b63964272397ed34864130912d2a87020
* [ ] PR https://github.com/seccomp/libseccomp/pull/134, Issue https://github.com/seccomp/libseccomp/issues/110

### Runc

* [ ] CGO (to build nsenter)
* [ ] `buildmode=pie` support
* [ ] Add `riscv64` to `libcontainer/system/syscall_linux_64.go`
* [ ] After upstreaming, update `x/sys` and `x/net` modules
* [ ] libseccomp-dev
* [ ] apparmor - (`$ sudo aa-status -> apparmor module is not loaded.`)

### Crun (https://github.com/giuseppe/crun)

No changes required, builds fine even without Kernel support for seccomp

* [ ] libseccomp

### Containerd (https://github.com/containerd/containerd/)

* [ ] PR https://github.com/containerd/containerd/pull/3328

### Docker

**Docker cli** (github.com/docker/cli)

Already builds successfully

* [x] Update `x/sys` and `x/net` modules in `vendor`. [PR](https://github.com/docker/cli/pull/1926)

**Docker daemon**

* [ ] Update `x/sys` and `x/net` modules in `vendor`.
* [ ] Update `etcd-io/bbolt` in `vendor`.
* [ ] `github.com/vishvananda/netns` - https://github.com/vishvananda/netns/pull/34
* [ ] Libnetwork PR - https://github.com/docker/libnetwork/pull/2389
* [x] PR https://github.com/moby/moby/pull/39327

### docker-init (https://github.com/krallin/tini)

No changes required. Just build and copy tini-static to /usr/local/bin/docker-init

### docker-proxy

Run dockerd as: `sudo dockerd  --userland-proxy=false`

--------------------------------------------------------------------------------

## Additional projects / libraries

### ETCD

Already builds succefully.

**Dependencies:**

* [ ] Update `kr/pty` (https://github.com/kr/pty/pull/81)
* [ ] Update `bbolt` (already upstreamed)
* [ ] `x/net`
* [ ] `x/sys`
* [ ] Backport changes to release 3.2 (used by Kubernetes)

### Kubernetes

* [ ] CGO
* [ ] ???

### Prometheus

Already builds successfully

* [ ] Opened PR https://github.com/prometheus/prometheus/pull/5621
* [ ] Wait PR from `kr/pty` gets merged to update module.
* [x] After upstreaming, update `x/sys` and `x/net` modules - `GO111MODULE=on go get -u golang.org/x/net && go get golang.org/x/sys && go mod tidy`
* [x] Apply patch from https://github.com/carlosedp/prometheus/commit/19e7ec54724240cde9768384736ff6ab88b1ace2

### Promu

Already builds successfully

* [ ] Opened PR https://github.com/prometheus/promu/pull/146
* [x] After upstreaming, update `x/sys` and `x/net` modules - `GO111MODULE=on go get -u golang.org/x/net && go get golang.org/x/sys && go mod tidy`

### SQlite

Repository mirror: https://github.com/CanonicalLtd/sqlite

* [ ] Update `config.guess` and `config.sub` to newer version. Posted to [mailing list](https://www.mail-archive.com/sqlite-users@mailinglists.sqlite.org/msg115489.html).

### LXD

* [x] LXC build successfully
* [ ] SQLite `config` update to build successfully
* [ ] CGO to build storage backends

### github.com/google/go-jsonnet

Repository on: https://github.com/google/go-jsonnet

* [x] Update `x/sys`
* [ ] PR https://github.com/google/go-jsonnet/pull/284

### github.com/github/hub

* [x] Update `x/sys`
* [x] PR https://github.com/github/hub/pull/2153

### github.com/labstack/echo

* [x] Update `x/sys`
* [x] Update `x/net`
* [x] PR https://github.com/labstack/echo/pull/1344

### github.com/labstack/gommon

* [x] Update `x/sys`
* [x] PR https://github.com/labstack/gommon/pull/32

### VNDR (https://github.com/LK4D4/vndr)

* [ ] PR https://github.com/LK4D4/vndr/pull/80


### Inlets (https://github.com/alexellis/inlets)

* [ ] PR https://github.com/alexellis/inlets/pull/70

--------------------------------------------------------------------------------

## Community

* Slack channel #risc-v on https://invite.slack.golangbridge.org

## References

* [RISC-V Assembly Programmer's Manual](https://github.com/riscv/riscv-asm-manual/blob/master/riscv-asm.md)
* [RISC-V ELF psABI specification](https://github.com/riscv/riscv-elf-psabi-doc/blob/master/riscv-elf.md)