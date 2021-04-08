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
sudo apt-get install autoconf automake autotools-dev curl libmpc-dev libmpfr-dev libgmp-dev gawk build-essential bison flex texinfo gperf libtool patchutils bc zlib1g-dev libexpat-dev libncurses-dev device-tree-compiler libssl-dev
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

# Linux Kernel (Stable)
git clone https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git
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
git checkout v2020.04
cp -v ../linux/arch/riscv/boot/dts/sifive/{hifive-unleashed-a00.dts,fu540-c000.dtsi} arch/riscv/dts/
CROSS_COMPILE=riscv64-unknown-linux-gnu- make sifive_fu540_defconfig
make menuconfig # if needed
CROSS_COMPILE=riscv64-unknown-linux-gnu- make -j 6
popd
```

This will generate the file `u-boot-dtb.bin` to be used by OpenSBI.

## Build OpenSBI

OpenSBI is the secondary bootloader. It's the one that calls U-Boot. The build process uses the U-Boot as it's payload to have it embedded into the same binary.

```sh
pushd opensbi
git checkout v0.8

make CROSS_COMPILE=riscv64-unknown-linux-gnu- \
     PLATFORM=sifive/fu540 \
     FW_PAYLOAD_PATH=../u-boot/u-boot-dtb.bin
popd
```

This will generate the file `build/platform/sifive/fu540/firmware/fw_payload.bin` that will be flashed into the SDcard later.

## Linux Kernel

### Kernel 5.8

Kernel 5.6 and up already supports RISC-V on Unleashed with no additional patches.

```sh
pushd linux
git checkout v5.8
```

As an option, you can apply cpufreq patch (has been reported that might not work with Microsemi expansion board, skip if this is your case) that allow controlling the clock of the processor. By default it runs at 1Ghz but some can run up to 1.4Ghz.

```sh
wget https://github.com/carlosedp/riscv-bringup/raw/master/unleashed/patches/cpufreq-5.5.patch
patch -p1 < cpufreq-5.5.patch
```

### Building the Kernel

Download config from the repo. This config has most requirements for containers and networking features built-in and is confirmed to work.

```sh
wget -O .config https://github.com/carlosedp/riscv-bringup/raw/master/unleashed/unleashed_config_5.8
```

Build the kernel. The `menuconfig` line is in case one want to customize any parameter. Also set the `$version` variable to be used later.

```sh
make CROSS_COMPILE=riscv64-unknown-linux-gnu- ARCH=riscv olddefconfig
make CROSS_COMPILE=riscv64-unknown-linux-gnu- ARCH=riscv menuconfig
make CROSS_COMPILE=riscv64-unknown-linux-gnu- ARCH=riscv -j6

# Build version string
version=`cat include/config/kernel.release`
echo $version

cp ./arch/riscv/boot/Image ./vmlinux-$version
cp ./arch/riscv/boot/dts/sifive/hifive-unleashed-a00.dtb ./dtb-$version
popd
```

Check if building produced the files `linux/arch/riscv/boot/Image` and `linux/arch/riscv/boot/dts/sifive/hifive-unleashed-a00.dtb`. This is the kernel file and the dtb that is the descriptor for the board hardware.

### Generating Kernel modules

```bash
cd linux/
rm -rf modules_install
mkdir -p modules_install
CROSS_COMPILE=riscv64-unknown-linux-gnu- ARCH=riscv make modules_install INSTALL_MOD_PATH=./modules_install
pushd ./modules_install/lib/modules
tar -cf kernel-modules-${version}.tar .
gzip kernel-modules-${version}.tar
popd
mv ./modules_install/lib/modules/kernel-modules-${version}.tar.gz .
cd ..
```

## Flashing to the SD Card

Create the SDcard. The partition typecodes are important here. I suggest using a card with 4GB or bigger. This depends on which rootfs you will use.

As the root filesystem, you can choose between downloading a pre-built Debian or Ubuntu or build the rootfs yourself.

The pre-built Debian tarball can be downloaded with: `wget -O rootfs.tar.bz2 https://github.com/carlosedp/riscv-bringup/releases/download/v1.0/debian-sid-riscv64-rootfs-20200108.tar.bz2`.

The pre-built Ubuntu Focal tarball can be downloaded with: `wget -O rootfs.tar.bz2 https://github.com/carlosedp/riscv-bringup/releases/download/v1.0/UbuntuFocal-riscv64-rootfs.tar.gz`.

If you want to build a Debian rootfs from scratch, [check this guide](https://github.com/carlosedp/riscv-bringup/blob/master/Debian-Rootfs-Guide.md).

If you want to build an Ubuntu rootfs from scratch, [check this guide](https://github.com/carlosedp/riscv-bringup/blob/master/Ubuntu-Rootfs-Guide.md).

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
default kernel-$version

label kernel-$version
        menu label Linux kernel-$version
        kernel /vmlinux-$version
        fdt /dtb-$version
        append earlyprintk rw root=/dev/mmcblk0p4 rhgb rootwait rootfstype=ext4 LANG=en_US.UTF-8 console=ttySIF0

label recovery-kernel-$version
        menu label Linux kernel-$version (recovery mode)
        kernel /vmlinux-$version
        fdt /dtb-$version
        append earlyprintk rw root=/dev/mmcblk0p4 rhgb rootwait rootfstype=ext4 LANG=en_US.UTF-8 console=ttySIF0 single
EOF

sudo cp ./linux/arch/riscv/boot/Image /mnt/vmlinux-$version
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

## Mount NBD volume

### On Server

Build latest version of NBD-Server

```bash
sudo apt-get install libglib2.0-dev
wget https://sourceforge.net/projects/nbd/files/nbd/3.19/nbd-3.19.tar.gz/download -O nbd-3.19.tar.gz
tar vxf nbd-3.19.tar.gz
cd nbd-3.19
./configure && make -j4
sudo cp nbd-server nbd-client /usr/local/bin
```

Generate systemd service and configuration file

```bash
cat << EOF | sudo tee -a /etc/systemd/system/nbd-server.service
[Unit]
Description=NBD server
After=network-online.target

[Service]
Type=forking
ExecStartPre=/sbin/modprobe nbd
ExecStart=/usr/local/bin/nbd-server --pid-file /var/run/nbd-server.pid -C /etc/nbd-server/config
PIDFile=/var/run/nbd-server.pid
ExecReload=/bin/kill -HUP $MAINPID

[Install]
WantedBy=multi-user.target
EOF

cat << EOF | sudo tee /etc/nbd-server/config
[generic]

# What follows are export definitions. You may create as much of them as
# you want, but the section header has to be unique.
[riscv]
exportname = /data/riscv-nbd50g.img
EOF

# Create disk image

sudo mkdir /data
sudo dd if=/dev/zero of=/data/riscv-nbd50g.img bs=1M count=50000
sudo mkfs.ext4 /data/riscv-nbd50g.img

sudo systemctl daemon-reload
sudo systemctl enable nbd-server.service
sudo systemctl start nbd-server.service
```

On Unleashed SBC:

```bash
sudo apt-get install libglib2.0-dev
wget https://sourceforge.net/projects/nbd/files/nbd/3.19/nbd-3.19.tar.gz/download -O nbd-3.19.tar.gz
tar vxf nbd-3.19.tar.gz
cd nbd-3.19
./configure && make -j4
sudo cp nbd-server nbd-client /usr/local/bin
sudo mkdir -p /mnt/riscv

# Create config file (Replace with server IP and export name)
cat << EOF | sudo tee -a /usr/local/etc/nbdtab
nbd0 192.168.15.15 riscv
EOF

# Create nbd-client service
cat << EOF | sudo tee -a /etc/systemd/system/nbd-client.service
[Unit]
Description=NBD client connection for nbd0
After=network-online.target

[Service]
Type=forking
ExecStartPre=/sbin/modprobe nbd
ExecStart=/usr/local/bin/nbd-client nbd0

[Install]
WantedBy=multi-user.target
EOF

# Create NBD mount
cat << EOF | sudo tee -a /etc/systemd/system/mnt-riscv.mount
[Unit]
Description=Mount Risc-V NBD Volume at Boot after the network is up but before docker
After=network-online.target nbd-client.service

[Mount]
What=/dev/nbd0
# What=UUID="d6058112-f6a6-4e75-8345-1662abe3b975"
Where=/mnt/riscv
Type=ext4
Options=defaults,noatime

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable nbd-client.service
sudo systemctl start nbd-client.service
sudo systemctl enable mnt-riscv.mount
sudo systemctl start mnt-riscv.mount
```

Configure Docker to use this path as data (Optional)

```bash
sudo vi /etc/systemd/system/docker.service
# Edit line:
ExecStart=/usr/local/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock --data-root=/mnt/riscv/docker
```


## References

* HiFive Unleashed OpenSBI - <https://github.com/riscv/opensbi/blob/master/docs/platform/sifive_fu540.md>
* HiFive Unleashed U-Boot - <https://gitlab.denx.de/u-boot/u-boot/blob/master/doc/board/sifive/fu540.rst>
* OpenSBI Deep Dive - <https://content.riscv.org/wp-content/uploads/2019/06/13.30-RISCV_OpenSBI_Deep_Dive_v5.pdf>
* The future of Supervisor Binary Interface(SBI) - <https://www.youtube.com/watch?v=d50mzglm2jU>
* <>
