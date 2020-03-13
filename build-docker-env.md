# Build requirements for Containers on Risc-V

This doc allows one to build and set the requirements to run containers on Risc-V architecture.

It has been tested on a SiFive Unleashed board.

Create a temporary place for building:

```bash
mkdir -p $HOME/riscv-docker
cd $HOME/riscv-docker
```

If building Debian `.deb`, create a destination dir:

```bash
mkdir -p $HOME/riscv-docker/debs
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
sudo make install
# For debs
DESTDIR=$HOME/riscv-docker/debs make install
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
sudo make install

# For debs
DESTDIR=$HOME/riscv-docker/debs make install
popd
```

## containerd

```bash
mkdir -p $GOPATH/src/github.com/containerd/
pushd $GOPATH/src/github.com/containerd/
git clone https://github.com/containerd/containerd
pushd containerd

make BUILDTAGS="no_btrfs" GO_GCFLAGS="-buildmode=default"
DESTDIR=/usr/local make install

# For debs
DESTDIR=$HOME/riscv-docker/debs/usr/local make install
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

# For debs
cp ./build/docker-linux-riscv64 $HOME/riscv-docker/debs/usr/local/bin
ln -sf /$HOME/riscv-docker/debs/usr/local/bin/docker-linux-riscv64 $HOME/riscv-docker/debs/usr/local/bin/docker
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

# For debs
cp tini-static $HOME/riscv-docker/debs/usr/local/bin/docker-init
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

# For debs
cp proxy $HOME/riscv-docker/debs/usr/local/bin/docker-proxy
popd
popd
```

## rootlesskit

```bash
mkdir $GOPATH/src/github.com/rootless-containers/
pushd $GOPATH/src/github.com/rootless-containers/
git clone https://github.com/rootless-containers/rootlesskit.git
pushd rootlesskit
make
sudo cp bin/* /usr/local/bin

# For debs
cp bin/* $HOME/riscv-docker/debs/usr/local/bin/
popd
popd
```

## dockerd

```bash
mkdir -p $GOPATH/src/github.com/docker/
pushd $GOPATH/src/github.com/docker/
git clone git://github.com/moby/moby docker
pushd docker
sudo cp ./contrib/dockerd-rootless.sh /usr/local/bin

# Apply PR https://github.com/moby/moby/pull/40664 until it gets merged
git cherry-pick fbfe6e0ca4adef7c1826d066a2163b4082641463

./hack/make.sh binary
sudo cp bundles/binary-daemon/dockerd-dev /usr/local/bin/docker
sudo cp bundles/binary-daemon/dockerd-dev $HOME/riscv-docker/debs/usr/local/bin/docker
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
cat << EOF | sudo tee -a /etc/systemd/system/containerd.service
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
EOF
```

`/etc/systemd/system/docker.service`

```bash
cat << EOF | sudo tee -a /etc/systemd/system/docker.service
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
BindsTo=containerd.service
After=network-online.target firewalld.service containerd.service
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
EOF
```

`/etc/systemd/system/docker.socket`

```bash
cat << EOF | sudo tee -a /etc/systemd/system/docker.socket
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
EOF
```

`/etc/docker/daemon.json` (optional)

```bash
cat << EOF | sudo tee -a /etc/docker/daemon.json
{
  "debug": true,
  "max-concurrent-uploads": 1
}
EOF
```


## Debian installer

```bash
mkdir -p $HOME/riscv-docker/debs/etc/systemd/system
mkdir -p $HOME/riscv-docker/debs/etc/docker

cp /etc/systemd/system/containerd.service $HOME/riscv-docker/debs/etc/systemd/system
cp /etc/systemd/system/docker.service $HOME/riscv-docker/debs/etc/systemd/system
cp /etc/systemd/system/docker.socket $HOME/riscv-docker/debs/etc/systemd/system
cp /etc/docker/daemon.json $HOME/riscv-docker/debs/etc/docker
```

Generate DEB files


```bash
mkdir -p $HOME/riscv-docker/debs/DEBIAN
cat << EOF | sudo tee -a $HOME/riscv-docker/debs/DEBIAN/control
Package: docker
Version: 19.03.5-dev
Architecture: riscv64
Maintainer: Carlos de Paula <carlosedp@gmail.com>
Depends: conntrack, ebtables, ethtool, iproute2, iptables, mount, socat, util-linux, libyajl-dev
Description: Docker Engine and CLI
EOF

cat << EOF | sudo tee -a $HOME/riscv-docker/debs/DEBIAN/postinst
#!/bin/sh
# see: dh_installdeb(1)

set -o errexit
set -o nounset

case "$1" in
    configure)
        # postinst configure step auto-starts it.
        echo "/usr/local/lib" > /etc/ld.so.conf.d/libseccomp-riscv64.conf
        ldconfig 2>/dev/null || true
        systemctl daemon-reload 2>/dev/null || true
        systemctl enable containerd 2>/dev/null || true
        systemctl enable docker 2>/dev/null || true
        systemctl restart containerd 2>/dev/null || true
        systemctl restart docker 2>/dev/null || true
        groupadd docker 2>/dev/null || true
        echo "To add permission to additional users, run: sudo usermod -aG docker $USER"
    ;;

    abort-upgrade|abort-remove|abort-deconfigure)
    ;;

    *)
        echo "postinst called with unknown argument \`$1'" >&2
        exit 1
    ;;
esac

# dh_installdeb will replace this with shell code automatically
# generated by other debhelper scripts.

#DEBHELPER#

exit 0
EOF

chmod +x $HOME/riscv-docker/debs/DEBIAN/postinst

cd $HOME/riscv-docker/
dpkg-deb -b debs docker-master-dev_riscv64.deb

```

Your tree should be similar to:

```bash
❯ tree
.
├── DEBIAN
│   ├── control
│   └── postinst
├── docker
│   └── daemon.json
├── etc
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
        │   ├── rootlessctl
        │   ├── rootlesskit
        │   ├── rootlesskit-docker-proxy
        │   └── scmp_sys_resolver
        ├── include
        │   ├── seccomp.h
        │   └── seccomp-syscalls.h
        ├── lib
        │   ├── libcrun.a
        │   ├── libcrun.la
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
                │   ├── crun.1
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
                    ├── seccomp_notify_alloc.3
                    ├── seccomp_notify_fd.3
                    ├── seccomp_notify_free.3
                    ├── seccomp_notify_id_valid.3
                    ├── seccomp_notify_receive.3
                    ├── seccomp_notify_respond.3
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
                    └── seccomp_version.3

15 directories, 66 files
```
