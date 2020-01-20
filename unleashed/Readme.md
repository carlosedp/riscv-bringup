# Building the SiFive Unleashed RISC-V board boot requirements

The objective of this guide is to provide an end-to-end solution on building the necessary packages to boot the SiFive Unleashed RISC-V board boot requirements.

This is still a moving target so the process might change in the future. I confirm that with used versions everything works.

The process is based on having OpenSBI (the second-stage boot loader) call U-Boot and this load the boot config (from `extlinux.conf`) allowing one to add and change Kernel versions.

Below is a diagram of the process:

```sh

                                    +----------------------------------+      Extlinux.conf                Linux
                                    |                                  |
                                    |         SBL - FW_PAYLOAD         |    +----------------+    +--------------------+
                                    |                                  |    |                |    |                    |
+--------------+   +----------+     |  +-----------+    +-----------+  |    | Unleashed Menu |    | Starting kernel ...|
|              |   |          |     |  |           |    |           |  |    |                |    | [0.00] Linux versio|
|  ROM - ZSBL  |   |  Loader  |     |  |           |    |           |  |    | 1. Kernel 5.5  |    | [0.00] Kernel comma|
|  In the SoC  +-->+  FSBL    +---->+  |  OpenSBI  +--->+   U-Boot  |  +--->+ 2. Kernel 5.6  +--->+ ..                 |
|              |   |          |     |  |           |    |   Payload |  |    |                |    | ...                |
+--------------+   +----------+     |  |           |    |           |  |    |                |    |                    |
                                    |  |           |    |           |  |    |                |    |                    |
                                    |  +-----------+    +-----------+  |    +----------------+    +--------------------+
                                    |                                  |
                                    +----------------------------------+

```

* **ZSBL** - Zero Stage Bootloader - Code in the ROM of the board. [Source](https://github.com/sifive/freedom-u540-c000-bootloader)
* **FSBL** - First Stage Bootloader - Loader that is called from ROM. [Source](https://github.com/sifive/freedom-u540-c000-bootloader)
* **SBL** -  Second Bootloader - OpenSBI - Supervisor Binary Interface. [Source](https://github.com/riscv/opensbi/)
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
mkdir unleashed
cd unleashed

# FSBL
git clone https://github.com/sifive/freedom-u540-c000-bootloader

# OpenSBI
git clone https://github.com/riscv/opensbi

# U-Boot
git clone https://github.com/U-Boot/U-Boot

# Linux Kernel
git clone https://github.com/torvalds/linux
```

## Build FSBL

First the FSBL. It requires some temporary patches until they get merged into the official repo.

```sh
pushd freedom-u540-c000-bootloader
wget https://github.com/carlosedp/riscv-bringup/raw/master/unleashed/patches/drop-unneeded-sectiosn-fix-string.patch
wget https://github.com/carlosedp/riscv-bringup/raw/master/unleashed/patches/enable-entire-l2-cache.patch

# Ignore error on one Makefile chunk
patch -p1 < drop-unneeded-sectiosn-fix-string.patch
patch -p1 < enable-entire-l2-cache.patch

make CROSSCOMPILE=riscv64-unknown-linux-gnu-
```

This will generate a `fsbl.bin` file that will be flashed into the SDcard later.

## Build U-Boot

U-Boot is the bootloader used to load the Kernels from the filesystem. It has a menu that allows one to select which version of the Kernel to use (if needed).

We use latest released version just replacing it's DTB with last one from the Linux Kernel. This is not extrictly necessary though.

```bash
pushd U-Boot
git checkout v2020.01
cp -v ../linux/arch/riscv/boot/dts/sifive/{hifive-unleashed-a00.dts,fu540-c000.dtsi} arch/riscv/dts/
CROSS_COMPILE=riscv64-unknown-linux-gnu- make sifive_fu540_defconfig
make menuconfig # if needed
CROSS_COMPILE=riscv64-unknown-linux-gnu- make -j 6
popd
```

This will generate the file `U-Boot.bin` to be used by OpenSBI.

## Build OpenSBI

OpenSBI is the secondary bootloader. It's the one that calls U-Boot. The build process uses the U-Boot as it's payload to have it embedded into the same binary.

```sh
pushd opensbi
make CROSS_COMPILE=riscv64-unknown-linux-gnu- \
     PLATFORM=sifive/fu540 \
     FW_PAYLOAD_PATH=../U-Boot/u-boot-dtb.bin
popd
```

This will generate the file `build/platform/sifive/fu540/firmware/fw_payload.bin` that will be flashed into the SDcard later.

## Build Linux Kernel

Not let's build the Linux kernel. First let's select the last mainline version that already supports RISC-V with no additional patches.

```sh
pushd linux
git checkout v5.5-rc5
```

Here one can apply cpufreq patches (does not work with Microsemi expansion board, skip if this is your case) that allow controlling the clock of the board.

```sh
wget https://github.com/carlosedp/riscv-bringup/raw/master/unleashed/patches/cpufreq.patch
patch -p1 < cpufreq.patch
```

By default the Unleashed board runs at 1Ghz but many can support 1.4Ghz. To test this, after having your board booted set the parameter with:

`echo 1400000 > /sys/devices/system/cpu/cpufreq/policy0/scaling_setspeed`

This need to be done after every reboot so you might want to add it to a script, systemd or cronjob. You board might not be stable or freeze so test after applying this before making the change permanent.

Download config from the repo. This config has most requirements for containers and networking features built-in and is confirmed to work.

```sh
wget -O .config https://github.com/carlosedp/riscv-bringup/raw/master/unleashed/unleashed_config
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

Check if building produced the files `linux/arch/riscv/boot/Image` and `linux/arch/riscv/boot/dts/sifive/hifive-unleashed-a00.dtb`. This is the kernel file and the dtb that is the descriptor for the board hardware.

## Flashing to the SD Card

Create the SDcard. The partition typecodes are important here. I suggest using a card with 4GB or bigger. This depends on which rootfs you will use.

I have available a Debian rootfs available for download at <https://github.com/carlosedp/riscv-bringup/releases/download/v1.0/debian-sid-riscv64-rootfs-20200108.tar.bz2>.

```sh
# Assuming your SD card is /dev/sdc. Adjust as necessary.

# Format card
sudo sgdisk -g --clear \
       --new=1::+128M   --change-name=1:'_/boot'          --typecode=1:0FC63DAF-8483-4772-8E79-3D69D8477DE4 \
       --new=2::+32K    --change-name=2:'_/fsbl'          --typecode=2:5B193300-FC78-40CD-8002-E86C45580B47 \
       --new=3::+8M:    --change-name=3:'_/opensbi-uboot' --typecode=3:2E54B353-1271-4842-806F-E436D6AF6985 \
       --new=4::-0      --change-name=4:'_/root'          --typecode=4:0FC63DAF-8483-4772-8E79-3D69D8477DE4 \
       /dev/sdc

# Flash FSBL
sudo dd if=freedom-u540-c000-bootloader/fsbl.bin of=/dev/sdc2 bs=1024
# Flash OpenSBI
sudo dd if=opensbi/build/platform/sifive/fu540/firmware/fw_payload.bin of=/dev/sdc3 bs=1024

# Generate /boot partition
sudo mkfs.ext2 /dev/sdc1
sudo mount /dev/sdc1 /mnt

sudo mkdir -p /mnt/boot/extlinux

cat << EOF | sudo tee /mnt/boot/extlinux/extlinux.conf
menu title SiFive Unleashed Boot Options
timeout 10
default unleashed-kernel-$version

label unleashed-kernel-$version
        kernel /vmlinuz-$version
        fdt /dtb-$version
        append earlyprintk rw root=/dev/mmcblk0p4 rhgb rootwait rootfstype=ext4 LANG=en_US.UTF-8
EOF

sudo cp ./linux/arch/riscv/boot/Image /mnt/vmlinuz-$version
sudo cp ./linux/arch/riscv/boot/dts/sifive/hifive-unleashed-a00.dtb /mnt/dtb-$version

sudo umount /mnt

# Create root partition

sudo mkfs.ext4 /dev/sdc4
sudo mount /dev/sdc4 /mnt
sudo tar vxf debian-sid-riscv64-rootfs-20200108.tar.bz2 -C /mnt --strip-components=1
# or flash your favorite distro rootfs
sudo umount /mnt

# Install Kernel Modules
pushd linux
sudo mount /dev/sdc4 /mnt
sudo make CROSS_COMPILE=riscv64-unknown-linux-gnu- ARCH=riscv modules_install INSTALL_MOD_PATH=/mnt
sudo umount /mnt
popd
```

You can mount the `boot` partition by adding a line like `/dev/mmcblk0p1 /boot ext2 defaults 0 0` to `/etc/fstab`. This allow access to the available kernels, adding new ones to this filesystem and modifying `/boot/extlinux/extlinux.conf` file

Use this with all the board switches in off position (facing inside the board).

Root password is *riscv*.
