git clone https://github.com/debuerreotype/debuerreotype
cd debuerreotype
./build.sh --arch=riscv64 --ports --qemu ./rootfs unstable 2020-03-10T00:00:00Z

cat << EOF | tee Dockerfile.debian
FROM scratch
ADD rootfs/20200310/riscv64/unstable/rootfs.tar.xz /
CMD ["bash"]
EOF

docker build -t carlosedp/debian:sid-riscv64 -f Dockerfile.debian .
docker push carlosedp/debian:sid-riscv64

cat << EOF | tee Dockerfile.debian-slim
FROM scratch
ADD rootfs/20200310/riscv64/unstable/slim/rootfs.tar.xz /
CMD ["bash"]
EOF

docker build -t carlosedp/debian:sid-slim-riscv64 -f Dockerfile.debian-slim .
docker push carlosedp/debian:sid-slim-riscv64
