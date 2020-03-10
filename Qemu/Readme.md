# RISC-V Qemu Virtual Machine

The objective of this guide is to provide an end-to-end solution on running a RISC-V Virtual machine and building the necessary packages to a fully-functional Qemu VM and it's boot requirements.

This is still a moving target so the process might change in the future. I confirm that with the versions used here, everything works.

The process is based on having OpenSBI (the second-stage boot loader) calling U-Boot and thru extlinux present a menu for available Kernel versions. Changing Kernel versions is a matter of adding Image and initrd to `extlinux.conf`.

There is also an alternative and simpler way to boot Qemu with by passing the Kernel image directly as a parameter bypassing U-Boot and the extlinux menu. More details in the section at the end of the guide.

Below is a diagram of the process:

```sh
+----------------------------------+      extlinux.conf                Linux
|                                  |
|         SBL - FW_PAYLOAD         |    +----------------+    +--------------------+
|                                  |    |                |    |                    |
|  +-----------+    +-----------+  |    | Unleashed Menu |    | Starting kernel ...|
|  |           |    |           |  |    |                |    | [0.00] Linux versio|
|  |           |    |           |  |    | 1. Kernel 5.5  |    | [0.00] Kernel comma|
+  |  OpenSBI  +--->+  U-Boot   |  +--->+ 2. Kernel 5.6  +--->+ ..                 |
|  |           |    |  Payload  |  |    |                |    | ...                |
|  |           |    |           |  |    |                |    |                    |
|  |           |    |           |  |    |                |    |                    |
|  +-----------+    +-----------+  |    +----------------+    +--------------------+
|                                  |
+----------------------------------+

```

* **SBL** -  Bootloader - OpenSBI - Supervisor Binary Interface. [Source](https://github.com/riscv/opensbi/)
* **U-Boot** - Universal Boot Loader. [Docs](https://www.denx.de/wiki/U-Boot)
* **Extlinux** - Syslinux compatible configuration to load Linux Kernel and DTB thru a configurable menu from a filesystem.

## Table of Contents <!-- omit in toc -->

* [RISC-V Qemu Virtual Machine](#risc-v-qemu-virtual-machine)
  * [Installing Qemu](#installing-qemu)
    * [Mac](#mac)
    * [Linux](#linux)
  * [Install Toolchain to build Kernel](#install-toolchain-to-build-kernel)
  * [Clone repositories](#clone-repositories)
  * [Build U-Boot](#build-u-boot)
  * [Build OpenSBI](#build-opensbi)
  * [Linux Kernel](#linux-kernel)
    * [Kernel 5.5](#kernel-55)
    * [Building the Kernel](#building-the-kernel)
    * [Generating Kernel modules](#generating-kernel-modules)
  * [Creating disk image](#creating-disk-image)
  * [Create tarball for distribution](#create-tarball-for-distribution)
  * [Remount Qcow image for changes](#remount-qcow-image-for-changes)
  * [Creating snapshots](#creating-snapshots)
  * [Simplified way to boot Qemu](#simplified-way-to-boot-qemu)
  * [References](#references)

## Installing Qemu

### Mac

On mac, installing Qemu is a matter of using [homebrew](https://brew.sh/) and installing with `brew install qemu`. Avoid using Qemu 4.2 due to a know problem.

In this case, after the install command above, edit the brewfile with `brew edit qemu` and change:

*  `url` line to: `url "https://download.qemu.org/qemu-4.1.1.tar.xz"`
*  `sha256` line to `sha256 "ed6fdbbdd272611446ff8036991e9b9f04a2ab2e3ffa9e79f3bab0eb9a95a1d2"`

After this, run `brew reinstall qemu -s` to rebuild and install the 4.1.1 version.

### Linux

On Debian or Ubuntu distros, install Qemu with:

```bash
sudo apt-get update
sudo apt-get install qemu-user-static qemu-system qemu-utils qemu-system-misc binfmt-support
```

On Fedora, install with `dnf install qemu`.


Depending on the distro, you might need to build Qemu from source.

## Install Toolchain to build Kernel

This process has been done in a amd64 VM running Ubuntu Xenial.

First install the RISC-V toolchain. You can build from source by using the commands below or download a pre-built one from [Bootlin](https://toolchains.bootlin.com/releases_riscv64.html).

```sh
git clone --recursive https://github.com/riscv/riscv-gnu-toolchain
cd riscv-gnu-toolchain
sudo apt-get install autoconf automake autotools-dev curl libmpc-dev libmpfr-dev libgmp-dev gawk build-essential bison flex texinfo gperf libtool patchutils bc zlib1g-dev libexpat-dev libncurses-dev device-tree-compiler
./configure --prefix=/opt/riscv
sudo make linux -j6
export PATH=/opt/riscv/bin:$PATH
echo "export PATH=/opt/riscv/bin:$PATH" >> ~/.bashrc
```

To use the bootlin toolchain you might need to adjust the `CROSS_COMPILE` variable to the correct GCC triplet.

## Clone repositories

Clone the required repositories. You need OpenSBI (bootloader), U-Boot and the Linux kernel. I keep all in one directory.

```sh
mkdir qemu-boot
cd qemu-boot

# OpenSBI
git clone https://github.com/riscv/opensbi

# U-Boot
git clone https://github.com/U-Boot/U-Boot u-boot

# Linux Kernel
git clone https://github.com/torvalds/linux
```

## Build U-Boot

U-Boot is the bootloader used to load the Kernels from the filesystem. It has a menu that allows you to select which version of the Kernel to use (if needed).

To allow booting on Qemu passing the configured CPU and memory parameters down to the Kernel, two patches are required. These might be upstreamed soon.

```bash
pushd u-boot
git checkout v2020.01

# Patch
wget https://github.com/carlosedp/riscv-bringup/raw/master/qemu/patches/uboot-riscv64-set-fdt_addr.patch
patch -p1 < uboot-riscv64-set-fdt_addr.patch
wget https://github.com/carlosedp/riscv-bringup/raw/master/qemu/patches/uboot-riscv64-bootargs-preboot.patch
patch -p1 < uboot-riscv64-bootargs-preboot.patch

# Build
CROSS_COMPILE=riscv64-unknown-linux-gnu- make qemu-riscv64_smode_defconfig
CROSS_COMPILE=riscv64-unknown-linux-gnu- make menuconfig # optional
CROSS_COMPILE=riscv64-unknown-linux-gnu- make -j6
popd
```

This will generate the file `u-boot.bin` to be used by OpenSBI.

## Build OpenSBI

OpenSBI is the bootloader. It's the one that calls U-Boot. The build process uses the U-Boot as it's payload to have it embedded into the same binary.

```sh
pushd opensbi
# Checkout a known compatible version
git checkout ac1c229

make CROSS_COMPILE=riscv64-unknown-linux-gnu- \
     PLATFORM=qemu/virt \
     FW_PAYLOAD_PATH=../u-boot/u-boot.bin
popd
```

This will generate the file `build/platform/qemu/virt/firmware/fw_payload.bin` that will be flashed into the SDcard later.

## Linux Kernel

### Kernel 5.5

Kernel 5.5 already supports RISC-V.

```sh
pushd linux
git checkout v5.5
```

Apply a patch fixing network module load.

```sh
wget https://github.com/carlosedp/riscv-bringup/raw/master/unleashed/patches/module_load.patch
patch -p1 < module_load.patch
```

### Building the Kernel

Download config from the repo. This config has most requirements for containers and networking features built-in and is confirmed to work. This config adds most networking features as modules and requires the `module_load.patch` patch. If you don't apply the patch, use the `unleashed_config` config to have the features baked-in.

```sh
wget -O .config https://github.com/carlosedp/riscv-bringup/raw/master/unleashed/unleashed_config_modules
```

If preferred to configure the Kernel based on defaults, run `make CROSS_COMPILE=riscv64-unknown-linux-gnu- ARCH=riscv defconfig`.

Build the kernel. The `menuconfig` line is in case you want to customize any parameter. Also set the `$version` variable to be used later.

```sh
make CROSS_COMPILE=riscv64-unknown-linux-gnu- ARCH=riscv olddefconfig
make CROSS_COMPILE=riscv64-unknown-linux-gnu- ARCH=riscv menuconfig
make CROSS_COMPILE=riscv64-unknown-linux-gnu- ARCH=riscv -j6

# Build version string
export VER=`cat Makefile |grep VERSION|head -1|awk  '{print $3}'`
export PATCH=`cat Makefile |grep PATCHLEVEL|head -1|awk  '{print $3}'`
export SUB=`cat Makefile |grep SUBLEVEL|head -1|awk  '{print $3}'`
export EXTRA=`cat Makefile |grep EXTRAVERSION|head -1|awk  '{print $3}'`
export DIRTY=`git diff --quiet || echo '-dirty'`
export version=$VER.$PATCH.$SUB$EXTRA$DIRTY
echo $version
popd
```

Check if building produced the file `linux/arch/riscv/boot/Image`.

### Generating Kernel modules

```bash
rm -rf modules_install
mkdir -p modules_install
CROSS_COMPILE=riscv64-unknown-linux-gnu- ARCH=riscv make modules_install INSTALL_MOD_PATH=./modules_install
pushd ./modules_install/lib/modules
tar -cf kernel-modules-${version}.tar .
gzip kernel-modules-${version}.tar
popd
mv ./modules_install/lib/modules/kernel-modules-${version}.tar.gz .
```

## Creating disk image

```bash
# Create and mount the disk image. Adjust maximum size on qemu-img below
qemu-img create -f qcow2 riscv64-debianrootfs-qemu.qcow2 10G
sudo modprobe nbd max_part=16
sudo qemu-nbd -c /dev/nbd0 riscv64-debianrootfs-qemu.qcow2

sudo sfdisk /dev/nbd0 << 'EOF'
label: dos
label-id: 0x17527589
device: /dev/nbd0
unit: sectors

/dev/nbd0p1 : start=        2048, type=83, bootable
EOF

sudo mkfs.ext4 /dev/nbd0p1
sudo e2label /dev/nbd0p1 rootfs

mkdir rootfs
sudo mount /dev/nbd0p1 rootfs
```

As the root filesystem, you can choose between downloading a pre-built Debian or build the rootfs yourself.

The pre-built tarball can be downloaded with: `wget -O debian-rootfs.tar.bz2 https://github.com/carlosedp/riscv-bringup/releases/download/v1.0/debian-sid-riscv64-rootfs-20200108.tar.bz2`.

Below are the instructions to build the rootfs from scratch:

<details><summary>Debian Rootfs from scratch</summary>

```bash
mkdir temp-rootfs

# Generate minimal bootstrap rootfs
sudo debootstrap --arch=riscv64 --variant=minbase --keyring /usr/share/keyrings/debian-ports-archive-keyring.gpg --include=debian-ports-archive-keyring unstable ./temp-rootfs http://deb.debian.org/debian-ports

# chroot to it. Requires "qemu-user-static qemu-system qemu-utils qemu-system-misc binfmt-support" packages on host
sudo chroot temp-rootfs /bin/bash

# Add unreleased packages
cat >/etc/apt/sources.list <<EOF
deb http://ftp.ports.debian.org/debian-ports/ sid main
deb http://deb.debian.org/debian-ports unstable main
deb http://deb.debian.org/debian-ports unreleased main
EOF

# Install essential packages
apt-get update
apt-get install --no-install-recommends -y util-linux haveged openntpd ntpdate openssh-server systemd kmod initramfs-tools conntrack ebtables ethtool iproute2 iptables mount socat ifupdown iputils-ping vim

# Create base config files
mkdir -p /etc/network
cat >/etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOF

cat >/etc/resolv.conf <<EOF
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF

cat >/etc/fstab <<EOF
LABEL=rootfs	/	ext4	user_xattr,errors=remount-ro	0	1
EOF

echo "debian-riscv" > /etc/hostname

# Disable some services on Qemu
ln -s /dev/null /etc/systemd/network/99-default.link
ln -sf /dev/null /etc/systemd/system/serial-getty@hvc0.service
sed -i 's/^DAEMON_OPTS="/DAEMON_OPTS="-s /' /etc/default/openntpd

# Set root passwd
echo "root:riscv" | chpasswd

# Exit chroot
exit

sudo tar -cSf debian-rootfs.tar -C temp-rootfs .
bzip2 debian-rootfs.tar
rm -rf temp-rootfs
```

<br></details>

Install Kernel, modules and unmount rootfs.

```bash
pushd rootfs
sudo tar vxf ../debian-rootfs.tar.bz2

# Unpack Kernel modules
sudo mkdir -p lib/modules
sudo tar vxf ../../../linux/kernel-modules-$version.tar.gz -C ./lib/modules

# Copy Kernel image file
sudo cp ../linux/arch/riscv/boot/Image vmlinux-$version

sudo mkdir -p boot/extlinux

# Create uboot extlinux file
cat << EOF | sudo tee boot/extlinux/extlinux.conf
menu title RISC-V Qemu Boot Options
timeout 100
default kernel-$version

label kernel-$version
        menu label Linux kernel-$version
        kernel /boot/vmlinux-$version
        initrd /boot/initrd.img-$version
        append earlyprintk rw root=/dev/vda1 rootwait rootfstype=ext4 LANG=en_US.UTF-8 console=ttyS0

label rescue-kernel-$version
        menu label Linux kernel-$version (recovery mode)
        kernel /boot/vmlinux-$version
        initrd /boot/initrd.img-$version
        append earlyprintk rw root=/dev/vda1 rootwait rootfstype=ext4 LANG=en_US.UTF-8 console=ttyS0 single
EOF

# Generate initrd on rootfs by using chroot
sudo chroot rootfs update-initramfs -k all -c

# Unmount and disconnect nbd
popd
sudo umount rootfs
sudo qemu-nbd -d /dev/nbd0
```

## Create tarball for distribution

```bash
mkdir qemu-vm
mv riscv64-debianrootfs-qemu.qcow2 qemu-vm
cp opensbi/build/platform/qemu/virt/firmware/fw_payload.bin qemu-vm

# Create start script
cat > qemu-vm/run_riscvVM.sh << 'EOF'
#!/bin/bash

# List here required TCP and UDP ports to be exposed on Qemu
TCPports=(2049 38188 8080 6443 8443 9090 9093)
UDPports=(2049 38188)

LocalSSHPort=22222

for port in ${TCPports[@]}
do
 ports=hostfwd=tcp::$port-:$port,$ports
done
for port in ${UDPports[@]}
do
 ports=hostfwd=udp::$port-:$port,$ports
done

ports=$ports"hostfwd=tcp::$LocalSSHPort-:22"

qemu-system-riscv64 \
    -nographic \
    -machine virt \
    -smp 4 \
    -m 4G \
    -bios fw_payload.bin \
    -device virtio-blk-device,drive=hd0 \
    -object rng-random,filename=/dev/urandom,id=rng0 \
    -device virtio-rng-device,rng=rng0 \
    -drive file=riscv64-debianrootfs-qemu.qcow2,format=qcow2,id=hd0 \
    -device virtio-net-device,netdev=usernet \
    -netdev user,id=usernet,$ports
EOF

# Create start script
cat > qemu-vm/ssh.sh << 'EOF'
#!/bin/bash
ssh -p 22222 -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@localhost
EOF

chmod +x qemu-vm/run_riscvVM.sh qemu-vm/ssh.sh
tar -cf riscv64-debian-qemuVM.tar qemu-vm
gzip riscv64-debian-qemuVM.tar
```

Now start the VM with the `run_riscvVM.sh` script. After boot, login on console or connect via SSH using `ssh.sh` in another terminal.

Kernel files are in `/boot`. You can add new versions or modify parameters on `/boot/extlinux/extlinux.conf` file.

Root password for the rootfs is *riscv*.

## Remount Qcow image for changes

```bash
sudo qemu-nbd -c /dev/nbd0 ./qemu-vm/riscv64-debianrootfs-qemu.qcow2
sudo partx -a /dev/nbd0

sudo mount /dev/nbd0p1 rootfs

# Edit as will

sudo umount rootfs
sudo qemu-nbd -d /dev/nbd0
```

## Creating snapshots

You can create a snapshot Qcow2 file that works as copy-on-write based on an existing base image.
This way you can keep the original image with base packages and the new snapshot holds all changes.

```bash
sudo qemu-img create -f qcow2 -b riscv64-debianrootfs-qemu.qcow2 snapshot-layer.qcow2
```

Then point the `-drive` parameter to this new layer. Keep both on same directory.

## Simplified way to boot Qemu

To bypass U-Boot and extlinux and pass the Linux kernel image directly to Qemu, create a dir and put together:

* The rootfs image (`riscv64-debianrootfs-qemu.qcow2`)
* Copy `fw_jump.elf` from `opensbi/build/platform/qemu/virt/firmware/`
* The Linux Kernel from `linux/arch/riscv/boot/Image` as `vmlinux-5.5.0` in this case.

Run Qemu with:

```bash
qemu-system-riscv64 \
    -nographic \
    -machine virt \
    -smp 4 \
    -m 4G \
    -bios default \
    -kernel vmlinux-5.5.0 \
    -append "console=ttyS0 root=/dev/vda1 rw" \
    -drive file=riscv64-debianrootfs-qemu.qcow2,format=qcow2,id=hd0 \
    -object rng-random,filename=/dev/urandom,id=rng0 \
    -device virtio-rng-device,rng=rng0
    -device virtio-net-device,netdev=usernet \
    -netdev user,id=usernet,hostfwd=tcp::22222-:22
```

You can also add more ports to the netdev line like the previous script.

## References

* Qemu OpenSBI - <https://github.com/riscv/opensbi/blob/master/docs/platform/qemu_virt.md>
* Qemu U-Boot - <https://gitlab.denx.de/u-boot/u-boot/blob/master/doc/board/emulation/qemu-riscv.rst>
* OpenSBI Deep Dive - <https://content.riscv.org/wp-content/uploads/2019/06/13.30-RISCV_OpenSBI_Deep_Dive_v5.pdf>
* The future of Supervisor Binary Interface(SBI) - <https://www.youtube.com/watch?v=d50mzglm2jU>
