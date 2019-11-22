# Creating a Kubernetes cluster on Risc-V

## Kubernetes

```bash
sudo apt update
sudo apt install -y conntrack ebtables socat

sudo update-alternatives --set iptables /usr/sbin/iptables-legacy
sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
sudo update-alternatives --set arptables /usr/sbin/arptables-legacy
sudo update-alternatives --set ebtables /usr/sbin/ebtables-legacy

wget https://github.com/carlosedp/riscv-bringup/releases/download/v1.0/kubernetes_1.16.0_riscv64.deb
sudo dpkg -i kubernetes_1.16.0_riscv64.deb

# Pre-fetch Kubernetes images
sudo kubeadm config images pull --image-repository=carlosedp --kubernetes-version 1.16.0

# Init cluster
sudo kubeadm init --image-repository=carlosedp --kubernetes-version 1.16.0 --ignore-preflight-errors SystemVerification,KubeletVersion --pod-network-cidr=10.244.0.0/16

# Adjust livenessProbe for apiserver
sudo cat /etc/kubernetes/manifests/kube-apiserver.yaml | sed -e 's/\(\s*initialDelaySeconds\).*/\1: 150/'
sudo cat /etc/kubernetes/manifests/kube-apiserver.yaml | sed -e 's/\(\s*timeoutSeconds\).*/\1: 60/'

kubectl apply -f https://gist.github.com/carlosedp/337b99a98cdcf5962f4a0e24a778994c/raw/kube-flannel.yml
```

## Deploy Nginx as a reverse proxy in front of Traefik NodePorts

```bash
sudo apt install nginx
sudo systemctl enable nginx
sudo cp k3s-nginx-revproxy.conf /etc/nginx/conf.d/
# Remove `server` entries from `/etc/nginx/nginx.conf`
sudo systemctl restart nginx
```

## K3s

## Deploy etcd as the storage backend for K3s

```bash
sudo cp etcd etcdctl /usr/local/bin
sudo mkdir -p /etc/etcd /var/lib/etcd
sudo cp certs/ca.pem certs/kubernetes-key.pem certs/kubernetes.pem /etc/etcd/
sudo cp systemd/etcd.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable etcd
sudo systemctl start etcd
```

Verifying:

```bash
sudo ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/etcd/ca.pem \
  --cert=/etc/etcd/kubernetes.pem \
  --key=/etc/etcd/kubernetes-key.pem
```

## Deploy the K3s cluster

```bash
sudo cp k3s kubectl /usr/local/bin

sudo cp systemd/k3s.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable k3s
sudo systemctl start k3s

mkdir $HOME/.kube
sudo cp /etc/rancher/k3s/k3s.yaml $HOME/.kube/config
chown $USER:$USER $HOME/.kube/config
```

## Patch Coredns to use riscv64 image

```bash
kubectl patch deployment coredns -n kube-system -p '{"spec":{"template":{"spec":{"containers":[{"name":"coredns","image":"carlosedp/coredns:v1.3.0-riscv64"}]}}}}'
```

## Deploy Nginx as a reverse proxy in front of Traefik NodePorts

```bash
sudo dnf install nginx
sudo systemctl enable nginx
sudo cp k3s-nginx-revproxy.conf /etc/nginx/conf.d/
# Remove `server` entries from `/etc/nginx/nginx.conf`
sudo systemctl restart nginx
```


## Deploy Traefik Ingress

```bash
# Remove K3d default Traefik
kubectl delete job -n kube-system helm-install-traefik

# Deploy
kubectl apply -f traefik-rbac.yaml
kubectl apply -f traefik-internal-configmap.yaml
kubectl apply -f traefik-internal-service.yaml
kubectl apply -f traefik-internal-deployment.yaml
```

## Deploy sample application

```bash
kubectl create deployment echo --image=carlosedp/echo-riscv
kubectl expose deploy echo --type=NodePort --port=80 --target-port=8080
kubectl apply -f echo-ingress.yaml
```

## Deploy OpenFaaS

```bash
kubectl apply -f openfaas/faas-namespace.yaml

# generate a random password
PASSWORD=$(head -c 12 /dev/urandom | shasum| cut -d' ' -f1)

kubectl -n openfaas create secret generic basic-auth \
--from-literal=basic-auth-user=admin \
--from-literal=basic-auth-password="$PASSWORD"

kubectl apply -f  ./openfaas/
```

## Generate deb install package


