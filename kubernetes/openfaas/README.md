# OpenFaaS

## On Kubernetes

When using these instructions you only want to use OpenFaaS for development.

### 1.0 Create namespaces

```sh
kubectl apply -f .
```

### 2.0 Create password

Generate secrets so that we can enable basic authentication for the gateway:

```sh
# generate a random password
PASSWORD=$(head -c 12 /dev/urandom | shasum| cut -d' ' -f1)

kubectl -n openfaas create secret generic basic-auth \
--from-literal=basic-auth-user=admin \
--from-literal=basic-auth-password="$PASSWORD"
```

### 3.0 Log in

Set `OPENFAAS_URL` (replace with your ingress IP/URL):

```sh
export OPENFAAS_URL=http://127.0.0.1:31112
```

If not using a NodePort, or if using KinD:

```sh
kubectl port-forward svc/gateway -n openfaas 31112:8080 &
```

Now log-in:

```sh
echo -n $PASSWORD | faas-cli login --password-stdin

faas-cli list

Function                        Invocations     Replicas
```

### 4.0 Deploy and test a function

```sh
faas-cli deploy --image carlosedp/faas-figlet:riscv64 --name figlet-riscv
echo "Hello World! I'm running OpenFaaS on Kubernetes in RISC-V" |faas-cli invoke figlet-riscv
```

Remove if desired:

```sh
faas-cli remove figlet-riscv
```

