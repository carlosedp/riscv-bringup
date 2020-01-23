# Building Go on your Risc-V VM or SBC

Golang is still not upstreamed so to build it from source, you will need a machine to do the initial bootstrap, copy this bootstraped tree to your Risc-V host or VM and then build the complete Go distribution. This bootstrap host can be a Windows, Mac or Linux.

<details><summary>Instructions</summary>

```bash
# On bootstrap Host
git clone https://github.com/4a6f656c/riscv-go
cd riscv-go/src
GOOS=linux GOARCH=riscv64 ./bootstrap.bash
# Copy the generated boostrap pack to the VM/SBC
scp -P 22222 ../../go-linux-riscv64-bootstrap.tbz root@localhost: # In case you use the VM provided above
```

Now on your Risc-V VM/SBC, clone the repository, export the path and bootstrap path you unpacked and build/test:

```bash
# On Risc-V Host
tar vxf go-linux-riscv64-bootstrap.tbz
git clone https://github.com/4a6f656c/riscv-go
cd riscv-go
export GOROOT_BOOTSTRAP=$HOME/go-linux-riscv64-bootstrap
export PATH="$(pwd)/misc/riscv:$(pwd)/bin:$PATH"
cd src
GOGC=off ./make.bash                            # Builds go on $HOME/riscv-go/bin that can be added to your path
GOGC=off  GO_TEST_TIMEOUT_SCALE=10 ./run.bash   # Tests the build
# Pack built Golang into a tarball
cd ..
sudo tar -cvf go-1.13dev-riscv64.tar --transform s/^riscv-go/go/ --exclude=pkg/obj --exclude .git riscv-go
```

</details>

Now you can use this go build for testing/developing other projects.