# RISC-V Debian Rootfs from scratch

This guide walks thru the build of a Debian root filesystem from scratch.

```bash
# Install pre-reqs
sudo apt-get install debootstrap qemu-user-static binfmt-support debian-ports-archive-keyring qemu-system qemu-utils qemu-system-misc

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
apt-get install --no-install-recommends -y util-linux haveged openntpd ntpdate openssh-server systemd kmod initramfs-tools conntrack ebtables ethtool iproute2 iptables mount socat ifupdown iputils-ping vim neofetch

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