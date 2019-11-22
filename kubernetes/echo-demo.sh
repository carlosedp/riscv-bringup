#!/bin/bash

# Create deployment
kubectl create deployment echo -n default --image=carlosedp/echo-riscv

# Expose service inside the cluster
kubectl expose deploy echo -n default --type=NodePort --port=80 --target-port=8080

# Create an ingress
cat <<EOF | kubectl apply -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: echo
  namespace: default
spec:
  rules:
  - host: echo.192.168.15.16.nip.io
    http:
      paths:
      - path: /
        backend:
          serviceName: echo
          servicePort: 80
EOF

echo "Deployment done!"
