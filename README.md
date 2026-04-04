# Kubernetes Learning Lab: Ingress & SSO (Colima Edition)

This project contains two self-contained implementations of a Kubernetes-based application with a FastAPI backend and a UI, optimized for **Colima**.

## Implementation Options

### 1. [Nginx Ingress (Basic)](nginx/README.md)
A simple setup using the standard **Nginx Ingress Controller** and local path-based routing.
- **Access**: `http://localhost:82`
- **Run**: `cd nginx && ./up.sh`
- **Key Concepts**: Services, Deployments, Ingress, Namespaces.

### 2. [Istio & SSO (Advanced)](istio-sso/README.md)
A modern service mesh setup replacing Nginx with **Istio** and adding **Backend Pattern SSO**.
- **Access**: `http://localhost:81`
- **Run**: `cd istio-sso && ./up.sh` (Fully automated configuration!)
- **Key Concepts**: Istio Gateways, OIDC, Authentication Proxies (Keycloak + oauth2-proxy).

---

## Environment Requirements
- **Runtime**: Colima (v0.5.0+)
- **Tools**: `kubectl`, `istioctl`, `docker`, `jq`, `yq`
- **No sudo required**: All examples run on `localhost` without modifying `/etc/hosts`.
