#!/bin/bash

if [ $# -ne 1 ]
then
    echo "Usage: $0 /dev/sdX"
    exit 1
fi
DISK=$1
UBOOT_IMG="u-boot.bin"
VFAT_IMG="hifive-unleashed-vfat.part"
ROOTFS="debian-rootfs.img"

VFAT="EBD0A0A2-B9E5-4433-87C0-68B6B72699C7"
LINUX="0FC63DAF-8483-4772-8E79-3D69D8477DE4"
UBOOT="5B193300-FC78-40CD-8002-E86C45580B47"
UBOOTENV="a09354ac-cd63-11e8-9aff-70b3d592f0fa"
VFAT_START=2048
VFAT_END=65502
UBOOT_START=1100
UBOOT_END=2020
UENV_START=1024
UENV_END=1099
VFAT_SIZE=63454
RESERVED_SIZE=2000

### Source files
MKIMAGE=mkimage
ITS=uboot-fit-image.its
UENV=uEnv.txt
BBL=bbl.bin
VMLINUX=$HOME/linux/vmlinux

export PATH=/home/carlosedp/riscv/bin:$PATH
# Build linux vmlinux
riscv64-unknown-linux-gnu-objcopy -O binary $VMLINUX vmlinux.bin
./mkimage -f uboot-fit-image.its -A riscv -O linux -T flat_dt image.fit
dd if=/dev/zero of=$(VFAT_IMG) bs=512 count=$(VFAT_SIZE)
/sbin/mkfs.vfat $(VFAT_IMG)
mkdir tmp-mnt
mount $(VFAT_IMG) tmp-mnt
cp image.fit tmp-mnt/hifiveu.fit
cp uEnv.txt tmp-mnt/uEnv.txt
umount tmp-mnt

if ! test -b $DISK; then
    echo "$DISK: is not a block device"
    exit 1
fi

DEVICE_NAME=`basename $DISK`
SD_SIZE=`cat /sys/block/$DEVICE_NAME/size`
ROOT_SIZE=`expr $SD_SIZE - $RESERVED_SIZE`

/sbin/sgdisk --clear -g \
    --new=1:$VFAT_START:$VFAT_END  --change-name=1:"Vfat Boot" --typecode=1:$VFAT   \
    --new=2:264192:$ROOT_SIZE --change-name=2:root --typecode=2:$LINUX \
    --new=3:$UBOOT_START:$UBOOT_END --change-name=3:uboot --typecode=3:$UBOOT \
    --new=4:$UENV_START:$UENV_END --change-name=4:uboot-env --typecode=4:$UBOOTENV \
    $DISK

/sbin/partprobe
sleep 1

PART1=${DISK}1
PART2=${DISK}2
PART3=${DISK}3
PART4=${DISK}4

echo "Flashing Vfat boot partition"
dd if=$VFAT_IMG of=$PART1 bs=4096
echo "Flashing RootFS"
dd if=$ROOTFS of=$PART2 bs=4096
echo "Flashing U-Boot"
dd if=$UBOOT_IMG of=$PART3 bs=4096

echo "Running e2fsck on rootfs"
e2fsck -f $PART2
echo "Resizing rootfs partition"
resize2fs $PART2

sync

echo ""
echo "SD Card created, boot and login with root/sifive"
echo ""