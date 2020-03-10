# Build requirements for Containers on Risc-V

This doc allows one to build and set the requirements to run containers on Risc-V architecture.

It has been tested on a SiFive Unleashed board.

Create a temporary place for building:

```
mkdir -p $HOME/riscv-docker
cd $HOME/riscv-docker
```

## Kernel seccomp support

Since Linux kernel 5.4, seccomp is supported.

## libseccomp

Libseccomp builds fine from its master branch. Will be included in version 2.5.

```bash
git clone git://github.com/seccomp/libseccomp
pushd libseccomp
./autogen.sh && ./configure
make
make install
popd
```

## crun

Since `runc`, Docker's default runtime does not build on riscv64 due to CGO dependency, we can use `crun`, a pure C based runtime that is OCI compliant.

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

make BUILDTAGS="no_btrfs" GO_GCFLAGS="-buildmode=default"

sudo ./bin/* /usr/local/bin/
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
index 427def3aca..bc7501f497 100755
--- a/hack/make.sh
+++ b/hack/make.sh
@@ -89,6 +89,11 @@ elif ${PKG_CONFIG} 'libsystemd-journal' 2> /dev/null; then
        DOCKER_BUILDTAGS+=" journald journald_compat"
 fi

+# riscv64 architecture does not support CGO so disable dependencies
+if [ "$(uname -m)" = 'riscv64' ]; then
+    DOCKER_BUILDTAGS+=" exclude_disk_quota exclude_graphdriver_devicemapper"
+fi
+
 # test whether "libdevmapper.h" is new enough to support deferred remove
 # functionality. We favour libdm_dlsym_deferred_remove over
 # libdm_no_deferred_remove in dynamic cases because the binary could be shipped
diff --git a/hack/make/.binary b/hack/make/.binary
index 2e194f2f10..329c3e5ae0 100644
--- a/hack/make/.binary
+++ b/hack/make/.binary
@@ -72,7 +72,7 @@ hash_files() {

        # -buildmode=pie is not supported on Windows and Linux on mips and riscv64.
        case "$(go env GOOS)/$(go env GOARCH)" in
-               windows/* | linux/mips*) ;;
+               windows/*|linux/mips*|linux/riscv*) ;;

                *)
                        BUILDFLAGS+=("-buildmode=pie")
EOF

./hack/make.sh binary
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

--------------------------------------------------------------------------------

## Systemd config

To enable Systemd support, create the following files:

`/etc/systemd/system/containerd.service`

```bash
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target

[Service]
ExecStartPre=-/sbin/modprobe overlay
ExecStart=/usr/local/bin/containerd
KillMode=process
Delegate=yes
LimitNOFILE=1048576
# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity

[Install]
WantedBy=multi-user.target
```

`/etc/systemd/system/docker.service`

```bash
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
BindsTo=containerd.service
After=network-online.target firewalld.service containerd.service mnt-riscv.mount
Wants=network-online.target
Requires=docker.socket

[Service]
Type=notify
# the default is not to use systemd for cgroups because the delegate issues still
# exists and systemd currently does not support the cgroup feature set required
# for containers run by docker
ExecStart=/usr/local/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock
ExecReload=/bin/kill -s HUP $MAINPID
TimeoutSec=0
RestartSec=2
Restart=always

# Note that StartLimit* options were moved from "Service" to "Unit" in systemd 229.
# Both the old, and new location are accepted by systemd 229 and up, so using the old location
# to make them work for either version of systemd.
StartLimitBurst=3

# Note that StartLimitInterval was renamed to StartLimitIntervalSec in systemd 230.
# Both the old, and new name are accepted by systemd 230 and up, so using the old name to make
# this option work for either version of systemd.
StartLimitInterval=60s

# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity

# Comment TasksMax if your systemd version does not supports it.
# Only systemd 226 and above support this option.
TasksMax=infinity

# set delegate yes so that systemd does not reset the cgroups of docker containers
Delegate=yes

# kill only the docker process, not all processes in the cgroup
KillMode=process

[Install]
WantedBy=multi-user.target
```

`/etc/systemd/system/docker.socket`

```bash
[Unit]
Description=Docker Socket for the API
PartOf=docker.service

[Socket]
ListenStream=/var/run/docker.sock
SocketMode=0660
SocketUser=root
SocketGroup=docker

[Install]
WantedBy=sockets.target
```

`/etc/docker/daemon.json`

```bash
{
  "debug": true,
  "max-concurrent-uploads": 1
}
```

Your tree should be similar to:

```
❯ tree
.
├── etc
│   ├── docker
│   │   └── daemon.json
│   └── systemd
│       └── system
│           ├── containerd.service
│           ├── docker.service
│           └── docker.socket
└── usr
    └── local
        ├── bin
        │   ├── containerd
        │   ├── containerd-shim
        │   ├── containerd-shim-runc-v1
        │   ├── containerd-shim-runc-v2
        │   ├── containerd-stress
        │   ├── crun
        │   ├── ctr
        │   ├── docker -> docker-linux-riscv64
        │   ├── dockerd
        │   ├── docker-init
        │   ├── docker-linux-riscv64
        │   ├── docker-proxy
        │   └── runc -> crun
        ├── include
        │   └── seccomp.h
        ├── lib
        │   ├── libseccomp.a
        │   ├── libseccomp.la
        │   ├── libseccomp.so -> libseccomp.so.0.0.0
        │   ├── libseccomp.so.0 -> libseccomp.so.0.0.0
        │   ├── libseccomp.so.0.0.0
        │   └── pkgconfig
        │       └── libseccomp.pc
        └── share
            └── man
                ├── man1
                │   └── scmp_sys_resolver.1
                └── man3
                    ├── seccomp_api_get.3
                    ├── seccomp_api_set.3
                    ├── seccomp_arch_add.3
                    ├── seccomp_arch_exist.3
                    ├── seccomp_arch_native.3
                    ├── seccomp_arch_remove.3
                    ├── seccomp_arch_resolve_name.3
                    ├── seccomp_attr_get.3
                    ├── seccomp_attr_set.3
                    ├── seccomp_export_bpf.3
                    ├── seccomp_export_pfc.3
                    ├── seccomp_init.3
                    ├── seccomp_load.3
                    ├── seccomp_merge.3
                    ├── seccomp_release.3
                    ├── seccomp_reset.3
                    ├── seccomp_rule_add.3
                    ├── seccomp_rule_add_array.3
                    ├── seccomp_rule_add_exact.3
                    ├── seccomp_rule_add_exact_array.3
                    ├── seccomp_syscall_priority.3
                    ├── seccomp_syscall_resolve_name.3
                    ├── seccomp_syscall_resolve_name_arch.3
                    ├── seccomp_syscall_resolve_name_rewrite.3
                    ├── seccomp_syscall_resolve_num_arch.3
```
