# RISC-V Qemu Virtual Machine <!-- omit in toc -->

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

* [Installing and running the Qemu VM](#installing-and-running-the-qemu-vm)
  * [Install on Mac](#install-on-mac)
  * [Install on Linux](#install-on-linux)
  * [Running](#running)
  * [SSH login into the guest](#ssh-login-into-the-guest)
  * [Additional config](#additional-config)
* [Building the Qemu VM Image](#building-the-qemu-vm-image)
  * [Install Toolchain to build Kernel](#install-toolchain-to-build-kernel)
  * [Clone repositories](#clone-repositories)
  * [Build U-Boot](#build-u-boot)
  * [Build OpenSBI](#build-opensbi)
  * [Linux Kernel](#linux-kernel)
    * [Kernel 5.6](#kernel-56)
    * [Building the Kernel](#building-the-kernel)
    * [Generating Kernel modules](#generating-kernel-modules)
  * [Creating disk image](#creating-disk-image)
  * [Create tarball for distribution](#create-tarball-for-distribution)
  * [Remount Qcow image for changes](#remount-qcow-image-for-changes)
  * [Creating snapshots](#creating-snapshots)
  * [Simplified way to boot Qemu](#simplified-way-to-boot-qemu)
* [References](#references)

## Installing and running the Qemu VM

### Install on Mac

On mac, installing Qemu is a matter of using [homebrew](https://brew.sh/) and installing with `brew install qemu`. Avoid using Qemu 4.2 due to a know problem.

In this case, after the install command above, edit the brewfile with `brew edit qemu` and change:

* `url` line to: `url "https://download.qemu.org/qemu-4.1.1.tar.xz"`
* `sha256` line to `sha256 "ed6fdbbdd272611446ff8036991e9b9f04a2ab2e3ffa9e79f3bab0eb9a95a1d2"`

After this, run `brew reinstall qemu -s` to rebuild and install the 4.1.1 version.

### Install on Linux

On Debian or Ubuntu distros, install Qemu with:

```bash
sudo apt-get update
sudo apt-get install qemu-user-static qemu-system qemu-utils qemu-system-misc binfmt-support
```

On Fedora, install with `dnf install qemu`.

Depending on the distro, you might need to build Qemu from source.

Currently there are three distributions of RISC-V VM pre-packaged for Qemu:

* [Debian Sid](https://github.com/carlosedp/riscv-bringup/releases/download/v1.0/debian-riscv64-QemuVM-202002.tar.gz)
* [Ubuntu Focal](https://github.com/carlosedp/riscv-bringup/releases/download/v1.0/UbuntuFocal-riscv64-QemuVM.tar.gz)
* [Fedora](https://drive.google.com/open?id=1MndnrABt3LUgEBVq-ZYWWzo1PVhxfOla)

### Running

To run the VM, use the script:

    ./run_riscvVM.sh

Avoid using Qemu 4.2 due to a FP bug. Version 4.1.1 works as expected.

### SSH login into the guest

    ssh -p 22222 -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@localhost

Login with user `root` and password `riscv`.

### Additional config

If required, you can add additional ports to be mapped between the VM and your host. Add into the startup script `run_riscvVM.sh` line the host and VM ports in the format `hostfwd=tcp::[HOST PORT]-:[VM PORT]`:

    -netdev user,id=usernet,hostfwd=tcp::10000-:22,hostfwd=tcp::2049-:2049,hostfwd=udp::2049-:2049,hostfwd=tcp::38188-:38188,hostfwd=udp::38188-:38188,hostfwd=tcp::8080-:8080

--------------------------------------------------------------------------------

## Building the Qemu VM Image

### Install Toolchain to build Kernel

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

To use the [bootlin](https://toolchains.bootlin.com/) toolchain you might need to adjust the `CROSS_COMPILE` variable to the correct GCC triplet.

### Clone repositories

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

### Build U-Boot

U-Boot is the bootloader used to load the Kernels from the filesystem. It has a menu that allows you to select which version of the Kernel to use (if needed).

To allow booting on Qemu passing the configured CPU and memory parameters down to the Kernel, two patches are required. These might be upstreamed soon.

```bash
pushd u-boot
git checkout v2020.04

# Patch
wget https://github.com/carlosedp/riscv-bringup/raw/master/Qemu/patches/uboot-riscv64-set-fdt_addr.patch
patch -p1 < uboot-riscv64-set-fdt_addr.patch
wget https://github.com/carlosedp/riscv-bringup/raw/master/Qemu/patches/uboot-riscv64-bootargs-preboot.patch
patch -p1 < uboot-riscv64-bootargs-preboot.patch

# Build
CROSS_COMPILE=riscv64-unknown-linux-gnu- make qemu-riscv64_smode_defconfig
CROSS_COMPILE=riscv64-unknown-linux-gnu- make menuconfig # optional
CROSS_COMPILE=riscv64-unknown-linux-gnu- make -j6
popd
```

This will generate the file `u-boot.bin` to be used by OpenSBI.

### Build OpenSBI

OpenSBI is the bootloader. It's the one that calls U-Boot. The build process uses the U-Boot as it's payload to have it embedded into the same binary.

```sh
pushd opensbi
# Checkout a known compatible version
git checkout v0.8

make CROSS_COMPILE=riscv64-unknown-linux-gnu- \
     PLATFORM=generic \
     FW_PAYLOAD_PATH=../u-boot/u-boot.bin
popd
```

According to the [docs](https://github.com/avpatel/opensbi#supported-sbi-version), OpenSBI v0.7 and up requires a Kernel version 5.7 or up.

This will generate the file `build/platform/qemu/virt/firmware/fw_payload.bin` that will be flashed into the SDcard later.

### Linux Kernel

#### Kernel 5.6

Kernel 5.6 already supports RISC-V.

```sh
pushd linux
git checkout v5.6
```

#### Building the Kernel

Download config from the repo. This config has most requirements for containers and networking features built-in and is confirmed to work. This config adds most networking features as modules.

```sh
wget -O .config https://github.com/carlosedp/riscv-bringup/raw/master/unleashed/unleashed_config_modules
```

If preferred to configure the Kernel based on defaults, run `make CROSS_COMPILE=riscv64-unknown-linux-gnu- ARCH=riscv defconfig`.

Build the kernel. The `menuconfig` line is in case you want to customize any parameter. Also set the `$version` variable to be used later.

```sh
make CROSS_COMPILE=riscv64-unknown-linux-gnu- ARCH=riscv olddefconfig
make CROSS_COMPILE=riscv64-unknown-linux-gnu- ARCH=riscv menuconfig
make CROSS_COMPILE=riscv64-unknown-linux-gnu- ARCH=riscv -j6
```

Check if building produced the file `linux/arch/riscv/boot/Image`.

#### Generating Kernel modules

```bash
rm -rf modules_install
mkdir -p modules_install
CROSS_COMPILE=riscv64-unknown-linux-gnu- ARCH=riscv make modules_install INSTALL_MOD_PATH=./modules_install
version=`cat include/config/kernel.release`
echo $version
pushd ./modules_install/lib/modules

tar -cf kernel-modules-${version}.tar .
gzip kernel-modules-${version}.tar
popd
mv ./modules_install/lib/modules/kernel-modules-${version}.tar.gz .
```

### Creating disk image

```bash
# Create and mount the disk image. Adjust maximum size on qemu-img below
qemu-img create -f qcow2 riscv64-QemuVM.qcow2 10G
sudo modprobe nbd max_part=16
sudo qemu-nbd -c /dev/nbd0 riscv64-QemuVM.qcow2

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

As the root filesystem, you can choose between downloading a pre-built Debian or Ubuntu or build the rootfs yourself.

The pre-built Debian tarball can be downloaded with: `wget -O rootfs.tar.bz2 https://github.com/carlosedp/riscv-bringup/releases/download/v1.0/debian-sid-riscv64-rootfs-20200108.tar.bz2`.

The pre-built Ubuntu Focal tarball can be downloaded with: `wget -O rootfs.tar.bz2 https://github.com/carlosedp/riscv-bringup/releases/download/v1.0/UbuntuFocal-riscv64-rootfs.tar.gz`.

If you want to build a Debian rootfs from scratch, [check this guide](https://github.com/carlosedp/riscv-bringup/blob/master/Debian-Rootfs-Guide.md).

If you want to build an Ubuntu rootfs from scratch, [check this guide](https://github.com/carlosedp/riscv-bringup/blob/master/Ubuntu-Rootfs-Guide.md).

Install Kernel, modules and unmount rootfs.

```bash
pushd rootfs
sudo tar vxf ../rootfs.tar.bz2 # or choosen rootfs

# Unpack Kernel modules
sudo mkdir -p lib/modules
sudo tar vxf ../../../linux/kernel-modules-$version.tar.gz -C ./lib/modules

sudo mkdir -p boot/extlinux

# Copy Kernel image file
sudo cp ../linux/arch/riscv/boot/Image boot/vmlinuz-$version

# Create uboot extlinux file
cat << EOF | sudo tee boot/extlinux/extlinux.conf
menu title RISC-V Qemu Boot Options
timeout 100
default kernel-$version

label kernel-$version
        menu label Linux kernel-$version
        kernel /boot/vmlinuz-$version
        initrd /boot/initrd.img-$version
        append earlyprintk rw root=/dev/vda1 rootwait rootfstype=ext4 LANG=en_US.UTF-8 console=ttyS0

label rescue-kernel-$version
        menu label Linux kernel-$version (recovery mode)
        kernel /boot/vmlinuz-$version
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

### Create tarball for distribution

```bash
mkdir qemu-vm
mv riscv64-QemuVM.qcow2 qemu-vm
cp opensbi/build/platform/generic/firmware/fw_payload.bin qemu-vm

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
    -drive file=riscv64-QemuVM.qcow2,format=qcow2,id=hd0 \
    -device virtio-net-device,netdev=usernet \
    -netdev user,id=usernet,$ports
EOF

# Create start script
cat > qemu-vm/ssh.sh << 'EOF'
#!/bin/bash
ssh -p 22222 -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@localhost
EOF

chmod +x qemu-vm/run_riscvVM.sh qemu-vm/ssh.sh
tar -cf riscv64-QemuVM.tar qemu-vm
gzip riscv64-QemuVM.tar
```

Now start the VM with the `run_riscvVM.sh` script. After boot, login on console or connect via SSH using `ssh.sh` in another terminal.

Kernel files are in `/boot`. You can add new versions or modify parameters on `/boot/extlinux/extlinux.conf` file.

Root password is *riscv*.

### Remount Qcow image for changes

```bash
sudo qemu-nbd -c /dev/nbd0 ./qemu-vm/riscv64-QemuVM.qcow2
sudo partx -a /dev/nbd0

sudo mount /dev/nbd0p1 rootfs

# Edit as will

sudo umount rootfs
sudo qemu-nbd -d /dev/nbd0
```

### Creating snapshots

You can create a snapshot Qcow2 file that works as copy-on-write based on an existing base image.
This way you can keep the original image with base packages and the new snapshot holds all changes.

```bash
sudo qemu-img create -f qcow2 -b riscv64-QemuVM.qcow2 snapshot-layer.qcow2
```

Then point the `-drive` parameter to this new layer. Keep both on same directory.

### Simplified way to boot Qemu

To bypass U-Boot and extlinux and pass the Linux kernel image directly to Qemu, create a dir and put together:

* The rootfs image (`riscv64-QemuVM.qcow2`)
* Copy `fw_jump.elf` from `opensbi/build/platform/qemu/virt/firmware/`
* The Linux Kernel from `linux/arch/riscv/boot/Image` as `vmlinuz-5.5.0` in this case.

Run Qemu with:

```bash
qemu-system-riscv64 \
    -nographic \
    -machine virt \
    -smp 4 \
    -m 4G \
    -bios default \
    -kernel vmlinuz-5.5.0 \
    -append "console=ttyS0 root=/dev/vda1 rw" \
    -drive file=riscv64-QemuVM.qcow2,format=qcow2,id=hd0 \
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
