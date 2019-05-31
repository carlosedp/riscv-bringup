# Risc-V bring-up tracker

The objective of this repository is to track the progress and pre-requisites to allow containers and Go applications on Risc-V.

## Pending upstream

* [ ] Go (https://github.com/golang/go/issues/27532 / https://github.com/4a6f656c/riscv-go)
* [ ] `golang.org/x/sys` (https://go-review.googlesource.com/c/sys/+/177799)

## PR submitted
* [ ] `kr/pty` (https://github.com/kr/pty/pull/81)

## Already upstreamed
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

* [ ] After upstreaming, update `x/sys` and `x/net` modules - `GO111MODULE=on go get -u golang.org/x/net && go get golang.org/x/sys && go mod tidy`
* [ ] Apply PR from https://github.com/carlosedp/prometheus/commit/19e7ec54724240cde9768384736ff6ab88b1ace2

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

### Kubernetes

* [ ] CGO
* [ ] ???
