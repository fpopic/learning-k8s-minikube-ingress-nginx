#!/bin/bash

set -euo pipefail

echo "🚀 Starting Colima with Kubernetes..."
colima start --kubernetes

# Ensure istioctl is available
if ! command -v istioctl &> /dev/null; then
    echo "istioctl not found, downloading to current directory..."
    curl -L https://istio.io/downloadIstio | sh -
    mv istio-*/bin/istioctl .
    rm -rf istio-*
    export PATH=$PATH:$(pwd)
fi

# We use port 81 for Istio to avoid a port conflict with Nginx Ingress (which uses 80).
# This allows both labs to coexist on the same local machine (Colima/Docker).
echo "📦 Installing Istio (demo profile) on port 81..."
istioctl install --set profile=demo \
  --set values.gateways.istio-ingressgateway.type=LoadBalancer \
  --set "values.gateways.istio-ingressgateway.ports[0].port=81" \
  --set "values.gateways.istio-ingressgateway.ports[0].targetPort=8080" \
  --set "values.gateways.istio-ingressgateway.ports[0].name=http2" \
  -y

echo "🛠️ Updating Mesh Config for SSO..."
kubectl get configmap istio -n istio-system -o yaml > istio-configmap.yaml
# data.mesh is a string containing YAML, so we parse, modify, and re-stringify it using yq
yq -i '
  .data.mesh |= (
    from_yaml | 
    .extensionProviders //= [] |
    (select(.extensionProviders | any(.name == "oauth2-proxy") | not) .extensionProviders += [{
      "name": "oauth2-proxy",
      "envoyExtAuthzHttp": {
        "service": "oauth2-proxy.learning.svc.cluster.local",
        "port": 4180,
        "includeHeadersInCheck": ["cookie", "authorization"],
        "headersToUpstreamOnAllow": ["x-auth-request-user", "x-auth-request-email", "x-auth-request-preferred-username"],
        "headersToDownstreamOnDeny": ["content-type", "set-cookie"]
      }
    }]) // . |
    to_yaml
  )
' istio-configmap.yaml
kubectl apply -f istio-configmap.yaml
rm istio-configmap.yaml
kubectl rollout restart deployment istiod -n istio-system

echo "🛠️ Building API and UI images..."
docker build -t hello-api:latest ../api
docker build -t hello-ui:latest ../ui

echo "🔐 Creating SSO secrets from .env..."
if [ ! -f .env ]; then
    echo "📄 .env file not found, creating from template..."
    cp .env.template .env
fi

# ... existing secret creation code ...
# Create or update the secret using pure shell
kubectl create secret generic sso-secrets \
  --namespace=learning \
  --from-env-file=.env \
  --dry-run=client -o yaml | kubectl apply -f -

echo "🚀 Applying Istio & SSO manifests..."
kubectl apply -f k8s/

echo "⏳ Waiting for Keycloak to be ready..."
kubectl rollout status deployment keycloak -n learning

echo "🛠️ Automating Keycloak configuration..."
# Function to wait for Keycloak URL to be reachable
until curl -s "http://localhost:81/auth/realms/master" > /dev/null; do
  echo "  > Waiting for Keycloak endpoint..."
  sleep 5
done

# 1. Get Admin Access Token
echo "  > Obtaining admin token..."
ADMIN_TOKEN=$(curl -s -d "client_id=admin-cli" -d "username=admin" -d "password=admin" -d "grant_type=password" \
  "http://localhost:81/auth/realms/master/protocol/openid-connect/token" | jq -r '.access_token')

# 2. Check if client exists, create if not
echo "  > Configuring oauth2-proxy client..."
CLIENT_EXISTS=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" \
  "http://localhost:81/auth/admin/realms/master/clients?clientId=oauth2-proxy" | jq '.[0] // empty')

if [ -z "$CLIENT_EXISTS" ]; then
    curl -s -X POST -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" \
      -d '{"clientId": "oauth2-proxy", "enabled": true, "protocol": "openid-connect", "publicClient": false, "serviceAccountsEnabled": true, "redirectUris": ["http://localhost:81/oauth2/callback"], "webOrigins": ["*"]}' \
      "http://localhost:81/auth/admin/realms/master/clients"
fi

# 3. Get Internal ID and Secret
INTERNAL_ID=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" \
  "http://localhost:81/auth/admin/realms/master/clients?clientId=oauth2-proxy" | jq -r '.[0].id')

CLIENT_SECRET=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" \
  "http://localhost:81/auth/admin/realms/master/clients/$INTERNAL_ID/client-secret" | jq -r '.value')

# 4. Update Admin User Email (avoid unverified email error)
echo "  > Verifying admin user email..."
USER_ID=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" \
  "http://localhost:81/auth/admin/realms/master/users?username=admin" | jq -r '.[0].id')

curl -s -X PUT -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" \
  -d '{"email": "admin@example.com", "emailVerified": true}' \
  "http://localhost:81/auth/admin/realms/master/users/$USER_ID"

# 5. Update .env file
echo "  > Updating .env with secret: ${CLIENT_SECRET:0:4}***"
# Using perl for Mac/Linux compatibility
perl -i -pe "s|^OAUTH2_PROXY_CLIENT_SECRET=.*|OAUTH2_PROXY_CLIENT_SECRET=$CLIENT_SECRET|" .env

# 6. Auto-generate Cookie Secret if missing
COOKIE_SECRET=$(grep "OAUTH2_PROXY_COOKIE_SECRET=" .env | cut -d'=' -f2)
if [ -z "$COOKIE_SECRET" ]; then
    echo "  > Generating fresh OAUTH2_PROXY_COOKIE_SECRET..."
    NEW_COOKIE_SECRET=$(python3 -c "import os, base64; print(base64.urlsafe_b64encode(os.urandom(32)).decode())")
    perl -i -pe "s|^OAUTH2_PROXY_COOKIE_SECRET=.*|OAUTH2_PROXY_COOKIE_SECRET=$NEW_COOKIE_SECRET|" .env
fi

# Validation: Check if the secret was actually set
CLIENT_SECRET_VALUE=$(grep "OAUTH2_PROXY_CLIENT_SECRET=" .env | cut -d'=' -f2)
if [ -z "$CLIENT_SECRET_VALUE" ]; then
    echo "❌ Error: OAUTH2_PROXY_CLIENT_SECRET is empty in .env. Keycloak automation might have failed."
    exit 1
fi

echo "🔐 Re-creating SSO secrets with the new client secret..."
kubectl create secret generic sso-secrets \
  --namespace=learning \
  --from-env-file=.env \
  --dry-run=client -o yaml | kubectl apply -f -

echo "🔄 Restarting oauth2-proxy to use the new secret..."
kubectl rollout restart deployment oauth2-proxy -n learning
kubectl rollout status deployment oauth2-proxy -n learning

echo "✅ Setup complete! Access http://localhost:81"
