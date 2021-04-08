# K3s Build and Run

* Disable any firewall daemon (firewalld, ufw, etc).

## Running K3s on RISC-V

Download the package from <https://github.com/carlosedp/riscv-bringup/releases/download/v1.0/k3s-v1.20.4-k3s1-riscv64.tar.gz>

```sh
mkdir k3s && cd k3s
wget https://github.com/carlosedp/riscv-bringup/releases/download/v1.0/k3s-v1.20.4-k3s1-riscv64.tar.gz

sudo cp k3s-riscv64 /usr/local/bin/k3s
sudo cp k3s-uninstall.sh /usr/local/bin/
sudo cp k3s-killall.sh /usr/local/bin/
sudo cp k3s.logrotate /etc/logrotate.d/k3s
sudo cp k3s.service /etc/systemd/system/k3s.service
sudo touch /etc/systemd/system/k3s.env

sudo systemctl daemon-reload
sudo systemctl enable k3s
sudo systemctl start k3s
```

Stopping and removing files:

```sh
sudo systemctl stop k3s
k3s-killall.sh

sudo rm -rf /etc/rancher/k3s
sudo rm -rf /run/k3s
sudo rm -rf /run/flannel
sudo rm -rf /var/lib/rancher/k3s
sudo rm -rf /var/lib/kubelet
```

### Patch Deployments to use our images supporting riscv64

Currently K3s tries to use it's standard images that do not support RISC-V so it's required to patch the deployments.

Patch images:

```sh
kubectl patch deployment coredns -n kube-system -p '{"spec":{"template":{"spec":{"containers":[{"name":"coredns","image":"carlosedp/coredns:v1.7.0"}]}}}}'
kubectl patch deployment metrics-server -n kube-system -p '{"spec":{"template":{"spec":{"containers":[{"name":"metrics-server","image":"carlosedp/metrics-server:v0.3.6"}]}}}}'
kubectl patch deployment local-path-provisioner -n kube-system -p '{"spec":{"template":{"spec":{"containers":[{"name":"local-path-provisioner","image":"carlosedp/local-path-provisioner:v0.0.19"}]}}}}'
```

Customize Traefik

```sh
DOMAIN=`ip route get 8.8.8.8 | sed -n '/src/{s/.*src *\([^ ]*\).*/\1/p;q}'`.nip.io

cat << EOF | sudo tee /var/lib/rancher/k3s/server/manifests/traefik-config.yaml
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: traefik
  namespace: kube-system
spec:
  valuesContent: |-
    image:
      name: carlosedp/traefik
      tag: v2.4.7
    rbac.enabled: true
    metrics.prometheus.enabled: true
    kubernetes.ingressEndpoint.useDefaultPublishedService: true
    ssl:
      insecureSkipVerify: true
      enabled: true
      permanentRedirect: false
    dashboard.enabled: "true"
    dashboard.domain: "traefik.$DOMAIN"
EOF
```


## Deploy a test application

```sh
DOMAIN=`ip route get 8.8.8.8 | sed -n '/src/{s/.*src *\([^ ]*\).*/\1/p;q}'`.nip.io
kubectl create deployment echo -n default --image=carlosedp/echo-riscv
kubectl create service clusterip echo -n default --tcp=8080

cat <<EOF | kubectl apply -f -
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: echo
  namespace: default
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$1
spec:
  rules:
    - host:  echo.$DOMAIN
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: echo
                port:
                  number: 8080
EOF

curl echo.$DOMAIN
```


## Building K3s and dependencies

### K3s

```sh
sudo apt install zstd
GO111MODULE=on go get github.com/mikefarah/yq/v3


# Apply patch
patch -p1 < ./k3s-1.20.patch

mkdir -p build/data
./scripts/download
go generate
# Until updated upstream
go get -u github.com/prometheus/procfs
./scripts/build
./scripts/package
```

## Images

```sh
docker.io/rancher/coredns-coredns:1.8.0 -> carlosedp/coredns:1.8.0
docker.io/rancher/klipper-helm:v0.4.3 -> carlosedp/klipper-helm:v0.4.3
docker.io/rancher/klipper-lb:v0.1.2 -> carlosedp/klipper-lb:v0.2.0
docker.io/rancher/library-busybox:1.32.1 -> carlosedp/busybox:1.31
docker.io/rancher/library-traefik:2.4.2 -> carlosedp/traefik:v2.4.7
docker.io/rancher/local-path-provisioner:v0.0.19 -> carlosedp/local-path-provisioner:v0.0.19
docker.io/rancher/metrics-server:v0.3.6 -> carlosedp/metrics-server:v0.3.6
docker.io/rancher/pause:3.1 -> carlosedp/pause:3.2
```
