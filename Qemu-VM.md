# Debian Risc-V Qemu VM

This pack contains a functional virtual machine to be used on Qemu emulating Debian Linux for Risc-V architecture.

The VM requires Qemu that can be easily installed with `sudo apt-get install qemu-system` on Ubuntu/Debian host, `dnf install qemu` on Fedora and `brew install qemu` on Mac.

The pack can be downloaded [here](https://github.com/carlosedp/riscv-bringup/releases/download/v1.0/debian-riscv64-QemuVM-202002.tar.gz).

## Running

To run the VM, use the script:

    ./run_debian.sh

Avoid using Qemu 4.2 due to a FP bug. Version 4.1.1 works as expected.

## SSH login into the guest

    ssh -p 22222 -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@localhost

Login with user `root` and password `riscv`.

## Additional config

If required, you can add additional ports to be mapped between the VM and your host. Add into the startup script `run_debian.sh` line the host and VM ports in the format `hostfwd=tcp::[HOST PORT]-:[VM PORT]`:

    -netdev user,id=usernet,hostfwd=tcp::10000-:22,hostfwd=tcp::2049-:2049,hostfwd=udp::2049-:2049,hostfwd=tcp::38188-:38188,hostfwd=udp::38188-:38188,hostfwd=tcp::8080-:8080

## Creating a scratch volume with the base backing image

If desired, this creates a secondary disk image that uses the original Debian root image as a base. This is similar to a snapshot making easy to revert back to the original machine state.

First create the snapshot:

    qemu-img create -f qcow2 -b debian-buster-sid-base.riscv64.qcow2 debian-scratch.qcow2

Than, replace line:

    -drive file=debian-buster-sid-base.riscv64.qcow2,format=qcow2,id=hd0 \

with line:

    -drive file=debian-scratch.qcow2,format=qcow2,id=hd0 \

on the startup script `run_debian.sh`.
