#!/bin/bash

set -euo pipefail

echo "🗑️ Deleting Nginx application manifests..."
kubectl delete -f k8s/ --ignore-not-found
kubectl delete ns learning-nginx --ignore-not-found

echo "✅ Nginx app cleaned up! (Nginx Controller remains installed)"
