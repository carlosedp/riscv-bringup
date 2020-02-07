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
git clone https://github.com/U-Boot/U-Boot u-boot

# Linux Kernel
git clone https://github.com/torvalds/linux
```

## Build FSBL

First the FSBL. It requires some temporary patches until they get merged into the official repo.

```sh
pushd freedom-u540-c000-bootloader
wget https://github.com/carlosedp/riscv-bringup/raw/master/unleashed/patches/fsbl-drop-unneeded-sectiosn-fix-string.patch
wget https://github.com/carlosedp/riscv-bringup/raw/master/unleashed/patches/fsbl-enable-entire-l2-cache.patch

# Ignore error on one Makefile chunk
patch -p1 < fsbl-drop-unneeded-sectiosn-fix-string.patch
patch -p1 < fsbl-enable-entire-l2-cache.patch

make CROSSCOMPILE=riscv64-unknown-linux-gnu-
```

This will generate a `fsbl.bin` file that will be flashed into the SDcard later.

## Build U-Boot

U-Boot is the bootloader used to load the Kernels from the filesystem. It has a menu that allows one to select which version of the Kernel to use (if needed).

We use latest released version just replacing it's DTB with last one from the Linux Kernel. This is not extrictly necessary though.

```bash
pushd u-boot
git checkout v2020.01
cp -v ../linux/arch/riscv/boot/dts/sifive/{hifive-unleashed-a00.dts,fu540-c000.dtsi} arch/riscv/dts/
CROSS_COMPILE=riscv64-unknown-linux-gnu- make sifive_fu540_defconfig
make menuconfig # if needed
CROSS_COMPILE=riscv64-unknown-linux-gnu- make -j 6
popd
```

This will generate the file `u-boot.bin` to be used by OpenSBI.

## Build OpenSBI

OpenSBI is the secondary bootloader. It's the one that calls U-Boot. The build process uses the U-Boot as it's payload to have it embedded into the same binary.

```sh
pushd opensbi

# Fix TLB flush errata on Unleashed board
patch -p1 < ../opensbi-tlb_unleashed.patch

make CROSS_COMPILE=riscv64-unknown-linux-gnu- \
     PLATFORM=sifive/fu540 \
     FW_PAYLOAD_PATH=../u-boot/u-boot.bin
popd
```

This will generate the file `build/platform/sifive/fu540/firmware/fw_payload.bin` that will be flashed into the SDcard later.

## Linux Kernel

<details><summary>Kernel 5.3</summary>

### Kernel 5.3-rc4

There are a few patches that add functionality or fixes issues on 5.3:

* SECCOMP support (already added to 5.5)
* CPUFREQ allowing changing CPU clock to 1.4Ghz (1Ghz by default)
* GMAC fix for the network interface ID
* Fix magic number generation

Checkout kernel:

```sh
pushd linux
git checkout v5.3-rc4
```

Apply patches:

```sh
wget https://github.com/carlosedp/riscv-bringup/raw/master/unleashed/patches/gmac-fix.patch
patch -p1 < gmac-fix.patch
wget https://github.com/carlosedp/riscv-bringup/raw/master/unleashed/patches/magicnumber-5.3.patch
patch -p1 < magicnumber-5.3.patch
wget https://github.com/carlosedp/riscv-bringup/raw/master/unleashed/patches/cpufreq-5.3.patch
patch -p1 < cpufreq-5.3.patch
wget https://github.com/carlosedp/riscv-bringup/raw/master/unleashed/patches/seccomp-5.3.patch
patch -p1 < seccomp-5.3.patch
wget https://github.com/carlosedp/riscv-bringup/raw/master/unleashed/patches/module_load.patch
patch -p1 < module_load.patch
```

</details>

### Kernel 5.5

Kernel 5.5 already supports RISC-V with no patches.

```sh
pushd linux
git checkout v5.5
```

Here one can apply cpufreq patch (has been reported that might not work with Microsemi expansion board, skip if this is your case) that allow controlling the clock of the board.

Also there is a patch fixing module load within relative jump range of the kernel text. Not required if bake-in (build kernel with embedded feature instead of module) the required fetures.

```sh
wget https://github.com/carlosedp/riscv-bringup/raw/master/unleashed/patches/cpufreq-5.5.patch
patch -p1 < cpufreq.patch
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

Check if building produced the files `linux/arch/riscv/boot/Image` and `linux/arch/riscv/boot/dts/sifive/hifive-unleashed-a00.dtb`. This is the kernel file and the dtb that is the descriptor for the board hardware.

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
sudo mkdir -p /mnt/extlinux

cat << EOF | sudo tee /mnt/extlinux/extlinux.conf
menu title SiFive Unleashed Boot Options
timeout 100
default unleashed-kernel-$version

label unleashed-kernel-$version
        kernel /vmlinuz-$version
        fdt /dtb-$version
        append earlyprintk rw root=/dev/mmcblk0p4 rhgb rootwait rootfstype=ext4 LANG=en_US.UTF-8 console=ttySIF0
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
srcdir=$(pwd)
sudo mount /dev/sdc4 /mnt
pushd /mnt/lib/modules
sudo tar vxf $srcdir/linux/kernel-modules-$version.tar.gz
popd
sudo umount /mnt
```

You can mount the `boot` partition using the command `echo "/dev/mmcblk0p1 /boot ext2 defaults 0 0" | sudo tee -a /etc/fstab` . This allow access to the available kernels just by adding new versions (vmlinux and dtb) to `/boot`  and modifying `/boot/extlinux/extlinux.conf` file.

Use this with all the board switches in off position (facing inside the board).

Root password for this rootfs is *riscv*.

## Set default clock speed

By default the Unleashed board runs at 1Ghz but many can support 1.4Ghz. To test this, after having your board booted set the parameter with:

The included patch supports `999999` and `1400000`  clocks.

`echo 1400000 > /sys/devices/system/cpu/cpufreq/policy0/scaling_setspeed`

This need to be done after every reboot so you might want to add it to a script, systemd or cronjob. You board might not be stable or freeze so test after applying this before making the change permanent. I have created a systemd service that starts/stops this configuration.

```bash
[Unit]
Description=Set HiFive Unleashed clock to 1.4Ghz

[Service]
Type=oneshot
RemainAfterExit=true

ExecStart=/bin/sh -c 'echo 1400000 > /sys/devices/system/cpu/cpufreq/policy0/scaling_setspeed'
ExecStop=/bin/sh -c 'echo 999999 > /sys/devices/system/cpu/cpufreq/policy0/scaling_setspeed'

[Install]
WantedBy=multi-user.target
```

After creating this file on `/etc/systemd/system/set-clockspeed.service`, enable with:

```bash
systemctl daemon-reload
systemctl start set-clockspeed

# To enable on every boot, do
systemctl enable set-clockspeed
```

## References

* HiFive Unleashed OpenSBI - <https://github.com/riscv/opensbi/blob/master/docs/platform/sifive_fu540.md>
* HiFive Unleashed U-Boot - <https://gitlab.denx.de/u-boot/u-boot/blob/master/doc/board/sifive/fu540.rst>
* OpenSBI Deep Dive - <https://content.riscv.org/wp-content/uploads/2019/06/13.30-RISCV_OpenSBI_Deep_Dive_v5.pdf>
* The future of Supervisor Binary Interface(SBI) - <https://www.youtube.com/watch?v=d50mzglm2jU>
* <>
