#!/bin/bash

# Create namespace

kubectl create namespace echo-demo
# Create deployment
kubectl create deployment echo -n echo-demo --image=carlosedp/echo-riscv

# Expose service inside the cluster
kubectl expose deploy echo -n echo-demo --type=NodePort --port=80 --target-port=8080

# Create an ingress
cat <<EOF | kubectl apply -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: echo
  namespace: echo-demo
spec:
  rules:
  - host: echo.192.168.1.17.nip.io
    http:
      paths:
      - path: /
        backend:
          serviceName: echo
          servicePort: 80
EOF

echo "Deployment done!"
