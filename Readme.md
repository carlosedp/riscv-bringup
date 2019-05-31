# Risc-V bring-up tracker

The objective of this repository is to track the progress and pre-requisites to allow containers and Go applications on Risc-V.

## Pending upstream

* [ ] Go (https://github.com/golang/go/issues/27532 / https://github.com/4a6f656c/riscv-go)

## PR submitted

* [ ] `kr/pty` (https://github.com/kr/pty/pull/81)
* [ ] Prometheus (https://github.com/prometheus/prometheus/pull/5621)

## Already upstreamed

* [x] `golang.org/x/sys` (https://go-review.googlesource.com/c/sys/+/177799)
* [x] `golang.org/x/net` (https://go-review.googlesource.com/c/net/+/177997)
* [x] `etcd-io/bbolt`

--------------------------------------------------------------------------------

## Projects

### Runc

* [ ] CGO (to build nsenter)
* [ ] `buildmode=pie` support
* [ ] Add `riscv64` to `libcontainer/system/syscall_linux_64.go`
* [ ] After upstreaming, update `x/sys` and `x/net` modules
* [ ] libseccomp-dev - Track (https://github.com/seccomp/libseccomp/pull/108) and Kernel support
* [ ] apparmor - (`$ sudo aa-status -> apparmor module is not loaded.`)

### Prometheus

Already builds successfully

* [ ] Opened PR https://github.com/prometheus/prometheus/pull/5621
* [ ] Wait PR from `kr/pty` gets merged to update module.
* [x] After upstreaming, update `x/sys` and `x/net` modules - `GO111MODULE=on go get -u golang.org/x/net && go get golang.org/x/sys && go mod tidy`
* [x] Apply PR from https://github.com/carlosedp/prometheus/commit/19e7ec54724240cde9768384736ff6ab88b1ace2

### Promu

Already builds successfully

* [ ] Opened PR https://github.com/prometheus/promu/pull/146
* [x] After upstreaming, update `x/sys` and `x/net` modules - `GO111MODULE=on go get -u golang.org/x/net && go get golang.org/x/sys && go mod tidy`

### Docker

**Docker daemon**

* [ ] Runc
* [ ] After upstreaming, update `x/sys` and `x/net` modules in `vendor`.
* [ ] `etcd-io/bbolt`
* [ ] `github.com/vishvananda/netns` - update to latest version or add `netns_linux_riscv64.go`
* [ ] `github.com/kr/pty/` - update to latest version

**Docker cli** (github.com/docker/cli)

Already builds successfully

* [ ] Update continuity version (https://github.com/containerd/continuity)
* [ ] After upstreaming, update `x/sys` and `x/net` modules in `vendor`.

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

### SQlite

Repository mirror: https://github.com/CanonicalLtd/sqlite

* [ ] Update `config.guess` and `config.sub` to newer version. Posted to mailing list.

### LXD

* [x] LXC build successfully
* [ ] SQLite `config` update to build successfully
* [ ] CGO to build storage backends

### github.com/google/go-jsonnet

Repository on: https://github.com/google/go-jsonnet

* [x] Update `x/sys`
* [ ] Submitted PR https://github.com/google/go-jsonnet/pull/284

### github.com/github/hub

* [x] Update `x/sys`
* [ ] Submitted PR https://github.com/github/hub/pull/2153

### github.com/labstack/echo

* [x] Update `x/sys`
* [x] Update `x/net`
* [ ] Submitted PR https://github.com/labstack/echo/pull/1344

### github.com/labstack/gommon

* [x] Update `x/sys`
* [ ] Submitted PR https://github.com/labstack/gommon/pull/32

--------------------------------------------------------------------------------

## References

* [RISC-V Assembly Programmer's Manual](https://github.com/riscv/riscv-asm-manual/blob/master/riscv-asm.md)
* [RISC-V ELF psABI specification](https://github.com/riscv/riscv-elf-psabi-doc/blob/master/riscv-elf.md)