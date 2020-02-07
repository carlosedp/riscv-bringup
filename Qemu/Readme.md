# Building Qemu boot requirements

The objective of this guide is to provide an end-to-end solution on building the necessary packages to boot a Qemu virtual machine with it's boot requirements.

This is still a moving target so the process might change in the future. I confirm that with used versions everything works.

The process is based on having OpenSBI (the second-stage boot loader) calling the Kernel directly . Changing Kernel versions is a matter of adjusting the start script/command.

Below is a diagram of the process:

```sh
+----------------------------------+      Extlinux.conf                Linux
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

## Clone repositories

Then, clone the required repositories. You need the FSBL (First stage bootloader), OpenSBI (Second stage bootloader), U-Boot and the Linux kernel. I keep all in one directory.

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

U-Boot is the bootloader used to load the Kernels from the filesystem. It has a menu that allows one to select which version of the Kernel to use (if needed).

To allow booting on Qemu passing the configured CPU and memory parameters down to the Kernel, two patches are required. These might be upstreamed soon.

```bash
pushd u-boot
git checkout v2020.01

wget https://github.com/carlosedp/riscv-bringup/raw/master/qemu/patches/uboot-riscv64-set-fdt_addr.patch
patch -p1 < uboot-riscv64-set-fdt_addr.patch
wget https://github.com/carlosedp/riscv-bringup/raw/master/qemu/patches/uboot-riscv64-bootargs-preboot.patch
patch -p1 < uboot-riscv64-bootargs-preboot.patch

CROSS_COMPILE=riscv64-unknown-linux-gnu- make qemu-riscv64_smode_defconfig
CROSS_COMPILE=riscv64-unknown-linux-gnu- make menuconfig # if needed
CROSS_COMPILE=riscv64-unknown-linux-gnu- make -j6
popd
```

This will generate the file `u-boot.bin` to be used by OpenSBI.

## Build OpenSBI

OpenSBI is the bootloader. It's the one that calls U-Boot. The build process uses the U-Boot as it's payload to have it embedded into the same binary.

```sh
pushd opensbi

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

There is a patch fixing network module load within relative jump range of the kernel text.

```sh
wget https://github.com/carlosedp/riscv-bringup/raw/master/unleashed/patches/module_load.patch
patch -p1 < module_load.patch
```

### Building the Kernel

Download config from the repo. This config has most requirements for containers and networking features built-in and is confirmed to work. This config adds most networking features as modules and requires the `module_load.patch` patch. If you don't apply the patch, use the `unleashed_config` config to have the features baked-in.

```sh
wget -O .config https://github.com/carlosedp/riscv-bringup/raw/master/unleashed/unleashed_config_modules
```

Build the kernel. The `menuconfig` line is in case one want to customize any parameter. Also set the `$version` variable to be used later.

```sh
make CROSS_COMPILE=riscv64-unknown-linux-gnu- ARCH=riscv olddefconfig
make CROSS_COMPILE=riscv64-unknown-linux-gnu- ARCH=riscv menuconfig
make CROSS_COMPILE=riscv64-unknown-linux-gnu- ARCH=riscv -j6

# Build version string
export VER=`cat Makefile |grep VERSION|head -1|awk  '{print $3}'`
export PATCH=`cat Makefile |grep PATCHLEVEL|head -1|awk  '{print $3}'`
export SUB=`cat Makefile |grep SUBLEVEL|head -1|awk  '{print $3}'`
export EXTRA=`cat Makefile |grep EXTRAVERSION|head -1|awk  '{print $3}'`
export version=$VER.$PATCH.$SUB$EXTRA
echo $version
popd
```

Check if building produced the files `linux/arch/riscv/boot/Image`.

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

cat > partition_table << 'EOF'
label: dos
label-id: 0x17527589
device: /dev/nbd0
unit: sectors

/dev/nbd0p1 : start=        2048, size=      262144, type=83, bootable
/dev/nbd0p2 : start=      264192,                    type=83
EOF

sudo sfdisk /dev/nbd0 < partition_table

sudo mkfs.ext2 /dev/nbd0p1
sudo mkfs.ext4 /dev/nbd0p2

# Build the boot partition
mkdir bootfs
sudo mount /dev/nbd0p1 bootfs
pushd bootfs
sudo mkdir -p extlinux

# Create uboot extlinux file
cat << EOF | sudo tee extlinux/extlinux.conf
menu title SiFive Unleashed Boot Options
timeout 100
default unleashed-kernel-$version

label unleashed-kernel-$version
        kernel /vmlinuz-$version
        append earlyprintk rw root=/dev/vda2 rhgb rootwait rootfstype=ext4 LANG=en_US.UTF-8 console=ttyS0
EOF

# Copy Kernel image file
sudo cp ../linux/arch/riscv/boot/Image vmlinuz-$version
popd

# Build the root partition
mkdir rootfs
sudo mount /dev/nbd0p2 rootfs

# For Debian RootFS
wget https://github.com/carlosedp/riscv-bringup/releases/download/v1.0/debian-sid-riscv64-rootfs-20200108.tar.bz2

pushd rootfs
sudo tar vxf ../debian-sid-riscv64-rootfs-20200108.tar.bz2

# Unpack Kernel modules
pushd lib/modules
sudo tar vxf ../../../linux/kernel-modules-$version.tar.gz
popd

# Unmount and disconnect nbd
popd
sudo umount rootfs
sudo umount bootfs
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

Now start the VM with the `run_riscvVM.sh` script. After boot, connect via SSH using `ssh.sh`.

You can mount the `boot` partition using the command `echo "/dev/mmcblk0p1 /boot ext2 defaults 0 0" | sudo tee -a /etc/fstab` . This allow access to the available kernels just by adding new versions (vmlinux) to `/boot`  and modifying `/boot/extlinux/extlinux.conf` file.

Root password for this rootfs is *riscv*.


## Remount Qcow image for changes

```bash
sudo qemu-nbd -c /dev/nbd0 ./qemu-vm/riscv64-debianrootfs-qemu.qcow2
sudo partx -a /dev/nbd0

sudo mount /dev/nbd0p1 bootfs
sudo mount /dev/nbd0p2 rootfs

# Edit as will

sudo umount bootfs
sudo umount rootfs
sudo qemu-nbd -d /dev/nbd0
```

## References

* Qemu OpenSBI - <https://github.com/riscv/opensbi/blob/master/docs/platform/qemu_virt.md>
* Qemu U-Boot - <https://gitlab.denx.de/u-boot/u-boot/blob/master/doc/board/emulation/qemu-riscv.rst>
* OpenSBI Deep Dive - <https://content.riscv.org/wp-content/uploads/2019/06/13.30-RISCV_OpenSBI_Deep_Dive_v5.pdf>
* The future of Supervisor Binary Interface(SBI) - <https://www.youtube.com/watch?v=d50mzglm2jU>
