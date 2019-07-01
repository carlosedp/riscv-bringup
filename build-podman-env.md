# Setup podman

Here is a quick guide on how to use and build [podman](https://podman.io/) for Risc-V architecture.

To install, download the tarball with all the requirements and run the `install.sh` script to quickly have it ready.

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

Building podman and it's pre-reqs.

### conmon

```bash
git clone https://github.com/containers/conmon $GOPATH/src/github.com/containers/conmon
dnf install -y make glib2-devel git gcc rpm-build golang
pushd $GOPATH/src/github.com/containers/conmon
make
sudo cp bin/conmon /usr/local/bin
popd
```

### crun

```bash
# Install pre-reqs
dnf install -y make python git gcc automake autoconf libcap-devel \
    systemd-devel yajl-devel libseccomp-devel libselinux-devel \
    go-md2man glibc-static python3-libmount libtool
git clone https://github.com/giuseppe/crun $GOPATH/src/github.com/giuseppe/crun
pushd $GOPATH/src/github.com/giuseppe/crun
./autogen.sh
./configure
make
sudo cp crun /usr/local/bin
sudo ln -sf /usr/local/bin/crun /usr/local/bin/runc
popd
```

### CNI plugins

```bash
git clone https://github.com/containernetworking/plugins.git $GOPATH/src/github.com/containernetworking/plugins
pushd $GOPATH/src/github.com/containernetworking/plugins
./build_linux.sh
sudo mkdir -p /usr/libexec/cni
sudo cp bin/* /usr/libexec/cni
popd
```

### podman

```bash
git clone https://github.com/containers/libpod $GOPATH/src/github.com/containers/libpod
pushd $GOPATH/src/github.com/containers/libpod
git fetch origin pull/3437/head:fix-nocgo
git checkout fix-nocgo
make BUILDTAGS="containers_image_openpgp containers_image_ostree_stub exclude_graphdriver_btrfs exclude_graphdriver_devicemapper exclude_disk_quota"
sudo make install
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
```

Create config file `/etc/containers/libpod.conf`:

```bash
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
```
