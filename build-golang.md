# Building Go on your RISC-V VM or SBC

Golang is still not upstreamed so to build it from source, you will need a machine to do the initial bootstrap, copy this bootstraped tree to your RISC-V host or VM and then build the complete Go distribution. This bootstrap host can be a Windows, Mac or Linux.

```bash
# On bootstrap Host
git clone https://github.com/golang/go
cd go/src
GOOS=linux GOARCH=riscv64 ./bootstrap.bash
# Copy the generated boostrap pack to the RISC-V VM/SBC
scp -P 22222 ../../go-linux-riscv64-bootstrap.tbz root@localhost: # In case you use the VM provided here
```

Now on your RISC-V VM/SBC, clone the repository, export the path and bootstrap path you unpacked and build/test:

```bash
# On RISC-V Host
tar vxf go-linux-riscv64-bootstrap.tbz
git clone https://github.com/golang/go
cd go/src
export GOROOT_BOOTSTRAP=$HOME/go-linux-riscv64-bootstrap
./make.bash                            # Builds go on $HOME/go/bin that can be added to your path
GO_TEST_TIMEOUT_SCALE=10 ./run.bash    # Tests the build
# Pack built Golang into a tarball
cd ..
sudo tar -cvf go-1.14rc1-riscv64.tar --exclude=pkg/obj --exclude .git go
```

Now you can use this go build for testing/developing other projects.
