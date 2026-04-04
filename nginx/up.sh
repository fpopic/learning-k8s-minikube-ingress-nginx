#!/bin/bash

set -euo pipefail

echo "🚀 Starting Colima with Kubernetes (disabling default Traefik)..."
colima start --kubernetes --kubernetes-disable traefik

echo "📦 Installing Nginx Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml

echo "⏳ Waiting for Nginx Ingress Controller to be ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

echo "🔧 Patching Nginx Ingress Controller to use port 82..."
# Port 82 is used to avoid conflict with standard HTTP (80) and Istio (81)
kubectl patch svc ingress-nginx-controller -n ingress-nginx --type='json' -p='[{"op": "replace", "path": "/spec/ports/0/port", "value": 82}]'

echo "🛠️ Building API and UI images..."
docker build -t hello-api:latest ../api
docker build -t hello-ui:latest ../ui

echo "🚀 Applying Nginx manifests in learning-nginx namespace..."
kubectl apply -f k8s/

echo "✅ Setup complete! Access http://localhost:82"
