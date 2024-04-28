# RISC-V Debian Rootfs from scratch

This guide walks thru the build of a Debian root filesystem from scratch.

```bash
# Install pre-reqs
sudo apt install debootstrap qemu qemu-user-static binfmt-support dpkg-cross debian-archive-keyring --no-install-recommends

# Generate minimal bootstrap rootfs
sudo debootstrap --arch=riscv64 --foreign --keyring /usr/share/keyrings/debian-archive-keyring.gpg --include=debian-archive-keyring sid ./temp-rootfs http://deb.debian.org/debian

# chroot to it. Requires "qemu-user-static qemu-system qemu-utils qemu-system-misc binfmt-support" packages on host
sudo chroot temp-rootfs /bin/bash
/debootstrap/debootstrap --second-stage

# Add unreleased packages
cat >/etc/apt/sources.list <<EOF
deb http://deb.debian.org/debian/dists sid main
deb http://deb.debian.org/debian/dists unstable main
deb http://deb.debian.org/debian/dists unreleased main
deb http://deb.debian.org/debian/dists experimental main
EOF

# Install essential packages
apt-get update
apt-get install --no-install-recommends -y util-linux haveged openssh-server systemd kmod initramfs-tools conntrack ebtables ethtool iproute2 iptables mount socat ifupdown iputils-ping vim neofetch sudo chrony pciutils

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

# Set root passwd
echo "root:riscv" | chpasswd

# Clean apt cache
apt-get clean
rm -rf /var/cache/apt/

# Exit chroot
exit

sudo tar -cSf debian-rootfs.tar -C temp-rootfs .
bzip2 debian-rootfs.tar
rm -rf temp-rootfs
```
