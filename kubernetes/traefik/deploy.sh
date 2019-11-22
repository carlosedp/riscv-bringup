#!/usr/bin/env bash

if [ -z "${KUBECONFIG}" ]; then
    export KUBECONFIG=~/.kube/config
fi

# CAUTION - setting NAMESPACE will deploy most components to the given namespace
# however some are hardcoded to 'monitoring'. Only use if you have reviewed all manifests.

if [ -z "${NAMESPACE}" ]; then
    NAMESPACE=kube-system
fi

kctl() {
    kubectl --namespace "$NAMESPACE" "$@"
}

# Deploy Traefik RBAC
kctl apply -f traefik-rbac.yaml

# Deploy internal Traefik and it's config
kctl apply -f traefik-configmap.yaml
kctl apply -f traefik-ingress.yaml
kctl apply -f traefik-service.yaml
kctl apply -f traefik-deployment.yaml

