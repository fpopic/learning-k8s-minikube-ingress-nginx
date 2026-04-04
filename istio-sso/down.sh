#!/bin/bash

set -euo pipefail

echo "🗑️ Deleting Istio & SSO application manifests..."
kubectl delete -f k8s/ --ignore-not-found
kubectl delete secret sso-secrets -n learning --ignore-not-found

echo "✅ Istio SSO app cleaned up! (Istio Mesh itself remains installed)"
