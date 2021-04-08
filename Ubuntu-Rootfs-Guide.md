# RISC-V Ubuntu Rootfs from scratch

This guide walks thru the build of a Ubuntu root filesystem from scratch. Ubuntu supports riscv64 packages from Focal, released on 04/2020.

Here we will build an Ubuntu Hirsute Hippo (latest version). I recommend doing this process can be done on a recent Ubuntu host (Focal or newer).

```bash
# Install pre-reqs
sudo apt install debootstrap qemu qemu-user-static binfmt-support dpkg-cross --no-install-recommends

# Generate minimal bootstrap rootfs
sudo debootstrap --arch=riscv64 --foreign hirsute ./temp-rootfs http://ports.ubuntu.com/ubuntu-ports

# chroot to it and finish debootstrap
sudo chroot temp-rootfs /bin/bash

/debootstrap/debootstrap --second-stage

# Add package sources
cat >/etc/apt/sources.list <<EOF
deb http://ports.ubuntu.com/ubuntu-ports hirsute main restricted

deb http://ports.ubuntu.com/ubuntu-ports hirsute-updates main restricted

deb http://ports.ubuntu.com/ubuntu-ports hirsute universe
deb http://ports.ubuntu.com/ubuntu-ports hirsute-updates universe

deb http://ports.ubuntu.com/ubuntu-ports hirsute multiverse
deb http://ports.ubuntu.com/ubuntu-ports hirsute-updates multiverse

deb http://ports.ubuntu.com/ubuntu-ports hirsute-backports main restricted universe multiverse

deb http://ports.ubuntu.com/ubuntu-ports hirsute-security main restricted
deb http://ports.ubuntu.com/ubuntu-ports hirsute-security universe
deb http://ports.ubuntu.com/ubuntu-ports hirsute-security multiverse
EOF

# Install essential packages
apt-get update
apt-get install --no-install-recommends -y util-linux haveged openssh-server systemd kmod initramfs-tools conntrack ebtables ethtool iproute2 iptables mount socat ifupdown iputils-ping vim dhcpcd5 neofetch sudo chrony

# Create base config files
mkdir -p /etc/network
cat >>/etc/network/interfaces <<EOF
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

echo "Ubuntu-riscv64" > /etc/hostname

# Disable some services on Qemu
ln -s /dev/null /etc/systemd/network/99-default.link
ln -sf /dev/null /etc/systemd/system/serial-getty@hvc0.service

# Set root passwd
echo "root:riscv" | chpasswd

sed -i "s/#PermitRootLogin.*/PermitRootLogin yes/g" /etc/ssh/sshd_config

# Clean APT cache and debootstrap dirs
rm -rf /var/cache/apt/

# Exit chroot
exit
sudo tar -cSf Ubuntu-Hippo-rootfs.tar -C temp-rootfs .
gzip Ubuntu-Hippo-rootfs.tar
rm -rf temp-rootfs
```
