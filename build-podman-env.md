# Setup podman

Here is a quick guide on how to use and build [podman](https://podman.io/) for Risc-V architecture.

To install the prebuilt pack on Debian, download the [deb package](https://github.com/carlosedp/riscv-bringup/releases/download/v1.0/podman-1.8.1_riscv64.deb) and install with `sudo apt install ./podman-1.6.4-dev_riscv64.deb`.

For other distros, download a [tarball here](https://github.com/carlosedp/riscv-bringup/releases/download/v1.0/podman-1.8.1_riscv64.tar.gz) with all the requirements and run the `install.sh` script to quickly have it ready.

Use this pack in the [Qemu Risc-V virtual machine](Qemu-VM.md).

## Using

```bash
# Podman information
sudo podman info

# Podman version
sudo podman version

# Run a container
sudo podman run -d --name echo --net host -p 8080:8080 carlosedp/echo_on_riscv

# Test
curl http://localhost:8080
curl http://localhost:8080?name=Joe
```

There is an issue on running containers on overlay networks [here](https://github.com/containers/libpod/issues/3462). For now, run the containers on `--net host`.

## Building

Building podman and it's pre-reqs. Requires Golang.

If building Debian `.deb`, create a destination dir:

```bash
mkdir -p $HOME/riscv-podman/debs
```

## libseccomp

Libseccomp builds fine from its master branch. Will be included in version 2.5.

```bash
git clone git://github.com/seccomp/libseccomp
pushd libseccomp
./autogen.sh && ./configure
make
sudo make install

# For debs
DESTDIR=$HOME/riscv-podman/debs make install
popd
```

### conmon

```bash
git clone https://github.com/containers/conmon $GOPATH/src/github.com/containers/conmon
dnf install -y make glib2-devel git gcc rpm-build
sudo apt install libglib2.0-dev make
pushd $GOPATH/src/github.com/containers/conmon
make
DESTDIR=$HOME/riscv-podman/debs sudo make install

# For debs
popd
```

### crun

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
DESTDIR=$HOME/riscv-podman/debs make install
pushd $HOME/riscv-podman/debs/usr/local/bin
ln -sf crun runc
popd
popd
```

### CNI plugins

```bash
git clone https://github.com/containernetworking/plugins.git $GOPATH/src/github.com/containernetworking/plugins
pushd $GOPATH/src/github.com/containernetworking/plugins
./build_linux.sh
sudo mkdir -p /opt/cni/bin
sudo cp bin/* /opt/cni/bin

# For debs
mkdir -p $HOME/riscv-podman/debs/opt/cni/bin
cp bin/* $HOME/riscv-podman/debs/opt/cni/bin
popd
```

### podman

```bash
git clone https://github.com/containers/libpod $GOPATH/src/github.com/containers/libpod
pushd $GOPATH/src/github.com/containers/libpod
make BUILDTAGS="containers_image_openpgp containers_image_ostree_stub exclude_graphdriver_btrfs exclude_disk_quota exclude_graphdriver_devicemapper systemd"
sudo cp bin/* /usr/local/bin

# For debs
cp bin/* /usr/local/bin
cp bin/* $HOME/riscv-podman/debs/usr/local/bin
popd
```

### Configuration files

```bash
sudo mkdir -p /etc/cni/net.d
curl -qsSL https://raw.githubusercontent.com/containers/libpod/master/cni/87-podman-bridge.conflist | sudo tee /etc/cni/net.d/99-loopback.conf
curl -qsSL https://raw.githubusercontent.com/containers/libpod/master/cni/87-podman-bridge.conflist | sudo tee /etc/cni/net.d/87-podman-bridge.conf

sudo mkdir -p /etc/containers
sudo curl https://raw.githubusercontent.com/projectatomic/registries/master/registries.fedora -o /etc/containers/registries.conf
sudo curl https://raw.githubusercontent.com/containers/skopeo/master/default-policy.json -o /etc/containers/policy.json

# For debs
mkdir -p $HOME/riscv-podman/debs/etc/cni/net.d/
mkdir -p $HOME/riscv-podman/debs/etc/containers
cp /etc/cni/net.d/99-loopback.conf $HOME/riscv-podman/debs/etc/cni/net.d/
cp /etc/cni/net.d/87-podman-bridge.conf $HOME/riscv-podman/debs/etc/cni/net.d/
cp /etc/containers/registries.conf $HOME/riscv-podman/debs/etc/containers/
cp /etc/containers/policy.json $HOME/riscv-podman/debs/etc/containers/
```

Create config file `/etc/containers/libpod.conf`:

```bash
cat << EOF | sudo tee -a /etc/containers/libpod.conf

# libpod.conf is the default configuration file for all tools using libpod to
# manage containers

# Default transport method for pulling and pushing for images
image_default_transport = "docker://"

# Paths to look for the Conmon container manager binary
conmon_path = [
	    "/usr/libexec/podman/conmon",
	    "/usr/local/libexec/podman/conmon",
	    "/usr/local/lib/podman/conmon",
	    "/usr/bin/conmon",
	    "/usr/sbin/conmon",
	    "/usr/local/bin/conmon",
	    "/usr/local/sbin/conmon"
]

# Environment variables to pass into conmon
conmon_env_vars = [
		"PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
]

# CGroup Manager - valid values are "systemd" and "cgroupfs"
cgroup_manager = "systemd"

# Container init binary
#init_path = "/usr/libexec/podman/catatonit"

# Directory for persistent libpod files (database, etc)
# By default, this will be configured relative to where containers/storage
# stores containers
# Uncomment to change location from this default
#static_dir = "/var/lib/containers/storage/libpod"

# Directory for temporary files. Must be tmpfs (wiped after reboot)
tmp_dir = "/var/run/libpod"

# Maximum size of log files (in bytes)
# -1 is unlimited
max_log_size = -1

# Whether to use chroot instead of pivot_root in the runtime
no_pivot_root = false

# Directory containing CNI plugin configuration files
cni_config_dir = "/etc/cni/net.d/"

# Directories where the CNI plugin binaries may be located
cni_plugin_dir = [
	       "/usr/libexec/cni",
	       "/usr/lib/cni",
	       "/usr/local/lib/cni",
	       "/opt/cni/bin"
]

# Default CNI network for libpod.
# If multiple CNI network configs are present, libpod will use the network with
# the name given here for containers unless explicitly overridden.
# The default here is set to the name we set in the
# 87-podman-bridge.conflist included in the repository.
# Not setting this, or setting it to the empty string, will use normal CNI
# precedence rules for selecting between multiple networks.
cni_default_network = "podman"

# Default libpod namespace
# If libpod is joined to a namespace, it will see only containers and pods
# that were created in the same namespace, and will create new containers and
# pods in that namespace.
# The default namespace is "", which corresponds to no namespace. When no
# namespace is set, all containers and pods are visible.
#namespace = ""

# Default infra (pause) image name for pod infra containers
infra_image = "k8s.gcr.io/pause:3.1"

# Default command to run the infra container
infra_command = "/pause"

# Determines whether libpod will reserve ports on the host when they are
# forwarded to containers. When enabled, when ports are forwarded to containers,
# they are held open by conmon as long as the container is running, ensuring that
# they cannot be reused by other programs on the host. However, this can cause
# significant memory usage if a container has many ports forwarded to it.
# Disabling this can save memory.
#enable_port_reservation = true

# Default libpod support for container labeling
# label=true

# Number of locks available for containers and pods.
# If this is changed, a lock renumber must be performed (e.g. with the
# 'podman system renumber' command).
num_locks = 2048

# Directory for libpod named volumes.
# By default, this will be configured relative to where containers/storage
# stores containers.
# Uncomment to change location from this default.
#volume_path = "/var/lib/containers/storage/volumes"

# Selects which logging mechanism to use for Podman events.  Valid values
# are `journald` or `file`.
# events_logger = "journald"

# Default OCI runtime
runtime = "crun"
lock_type ="file"

# List of the OCI runtimes that support --format=json.  When json is supported
# libpod will use it for reporting nicer errors.
runtime_supports_json = ["runc"]

# Paths to look for a valid OCI runtime (runc, runv, etc)
[runtimes]
runc = [
	    "/usr/bin/runc",
	    "/usr/sbin/runc",
	    "/usr/local/bin/runc",
	    "/usr/local/sbin/runc",
	    "/sbin/runc",
	    "/bin/runc",
	    "/usr/lib/cri-o-runc/sbin/runc"
]

crun = [
	    "/usr/bin/crun",
	    "/usr/local/bin/crun",
]

# The [runtimes] table MUST be the last thing in this file.
# (Unless another table is added)
# TOML does not provide a way to end a table other than a further table being
# defined, so every key hereafter will be part of [runtimes] and not the main
# config.
EOF
```

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

## Debian installer

```bash
mkdir -p $HOME/riscv-podman/debs/etc/systemd/system

cp /etc/systemd/system/containerd.service $HOME/riscv-podman/debs/etc/systemd/system
```

Generate DEB files


```bash
mkdir -p $HOME/riscv-podman/debs/DEBIAN
cat << EOF | sudo tee -a $HOME/riscv-podman/debs/DEBIAN/control
Package: podman
Version: 1.8.1
Architecture: riscv64
Maintainer: Carlos de Paula <carlosedp@gmail.com>
Depends: conntrack, ebtables, iproute2, iptables
Description: Podman
EOF

cat << EOF | sudo tee -a $HOME/riscv-podman/debs/DEBIAN/postinst
#!/bin/sh
# see: dh_installdeb(1)

set -o errexit
set -o nounset

case "$1" in
    configure)
        # postinst configure step auto-starts it.
        echo "/usr/local/lib" > /etc/ld.so.conf.d/libseccomp-riscv64.conf
        ldconfig 2>/dev/null || true
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

chmod +x $HOME/riscv-podman/debs/DEBIAN/postinst

cd $HOME/riscv-podman/
dpkg-deb -b debs podman-1.8.1-dev_riscv64.deb
```

Directory Tree

```
/home/carlosedp/work/debs/podman
├── DEBIAN
│   ├── control
│   └── postinst
├── etc
│   ├── cni
│   │   └── net.d
│   │       ├── 87-podman-bridge.conflist
│   │       └── 99-loopback.conf
│   └── containers
│       ├── libpod.conf
│       ├── policy.json
│       └── registries.conf
├── opt
│   └── cni
│       └── bin
│           ├── bandwidth
│           ├── bridge
│           ├── dhcp
│           ├── firewall
│           ├── flannel
│           ├── host-device
│           ├── host-local
│           ├── ipvlan
│           ├── loopback
│           ├── macvlan
│           ├── portmap
│           ├── ptp
│           ├── sbr
│           ├── static
│           ├── tuning
│           └── vlan
└── usr
    └── local
        ├── bin
        │   ├── conmon
        │   ├── crun
        │   ├── podman
        │   └── podman-remote
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
                    └── seccomp_version.3
```