# Building Go on your RISC-V VM or SBC

Golang is already upstream but no packaged binaries are provided. To build it from source, a previously built Go or build yourself a golang bootstrap. Copy this bootstraped tree to your RISC-V host or VM and then build the complete Go distribution. This bootstrap host can be a Windows, Mac or Linux.

You can get prebuilt packages in the releases section and skip bootstrap generation.

```bash
# On bootstrap Host
git clone https://github.com/golang/go
cd go/src
GOOS=linux GOARCH=riscv64 ./bootstrap.bash
# Copy the generated boostrap pack to the RISC-V VM/SBC
scp -P 22222 ../../go-linux-riscv64-bootstrap.tbz root@localhost: # In case you use the VM provided here
```

On your RISC-V VM/SBC, clone the repository, export the path to go and build/test:

```bash
# On RISC-V Host
tar vxf go-linux-riscv64-bootstrap.tbz      # or use an already unpacked Go
git clone https://github.com/golang/go
# Checkout latest tag
git checkout $(git --git-dir ./go/.git describe --tags)

pushd go/src
export GOROOT_BOOTSTRAP=$HOME/go-linux-riscv64-bootstrap    # Or adjust to your local go
./make.bash                            # Builds go
GO_TEST_TIMEOUT_SCALE=10 ./run.bash    # Tests the build
# Pack built Golang into a tarball
popd
tar -cvf $(git --git-dir ./go/.git describe --tags).$(uname -s |tr [:upper:] [:lower:])-$(uname -m).tar --exclude=pkg/obj --exclude=.git go
```

Now you can use this go build for testing/developing other projects.
