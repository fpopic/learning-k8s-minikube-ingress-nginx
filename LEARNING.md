# Learning Lab: Kubernetes Ingress & Backend SSO Pattern

This project documents the evolution from a basic Nginx Ingress setup to an enterprise-grade **Istio Service Mesh** with **Single Sign-On (SSO)**.

## 1. Architecture Overview

### Lab A: Basic Nginx Ingress
- **Ingress Controller**: Nginx (`ingress-nginx`).
- **Routing**: Path-based (`/api/*` vs `/*`).
- **Security**: None (Public access).
- **Port**: 82 (Avoids conflict with port 80/81).

### Lab B: Advanced Istio SSO
- **Service Mesh**: Istio (`istiod`).
- **Ingress**: Istio Ingress Gateway.
- **SSO Pattern**: Backend Pattern SSO (OIDC).
- **IDP**: Keycloak (representing Microsoft Azure AD in enterprise).
- **Auth Proxy**: `oauth2-proxy`.
- **Port**: 81 (Coexists with Nginx).

## 2. The Backend SSO Pattern
Instead of implementing OIDC logic (tokens, redirects, validation) inside the FastAPI application, we use the **Sidecar/Proxy Pattern**:

1.  **Request**: User hits Istio Gateway.
2.  **Intercept**: Istio's `AuthorizationPolicy` sends a check request to `oauth2-proxy`.
3.  **Validate**: `oauth2-proxy` checks for a session cookie. If missing, it redirects to the IDP (Keycloak).
4.  **Inject**: Once validated, the proxy returns `200 OK` to Istio and tells it to inject HTTP headers:
    - `X-Auth-Request-User`
    - `X-Auth-Request-Email`
5.  **Clean Code**: The FastAPI backend simply reads these headers. It doesn't even know it's behind OIDC.

## 3. Key Technical Lessons

### Ingress & Local DNS
- **Istio Gateway Validation**: The Istio Gateway resource requires an FQDN or a wildcard `*`. It rejects "short names" like `localhost`. However, the **VirtualService** can use `localhost` to filter traffic once it passes the gateway.
- **Port Preservation**: When running on non-standard ports (like 81), Keycloak redirects often drop the port. Setting `KC_HOSTNAME_URL` and `KC_HOSTNAME_PORT` explicitly fixes this.

### OIDC & User Requirements
- **Email Verification**: Many OIDC proxies (like `oauth2-proxy`) require a verified email claim by default. Keycloak's default `admin` user has no email, causing 500 errors unless updated or the `--insecure-oidc-allow-unverified-email` flag is used.
- **Cookie Security**: For local `http://localhost` testing, ensure `--cookie-secure=false` is set, otherwise browsers will block the session cookie.

### Automation Best Practices
- **REST API for Config**: Instead of manual UI setup, use the IDP's REST API (Keycloak Admin API) to create clients and fetch secrets during the setup script.
- **Secret Management**: Move sensitive data (Client Secrets, Admin Passwords) from YAML manifests to a `.env` file and use Kubernetes `Secrets` injected via `envFrom` or `secretKeyRef`.
- **Tooling**: `jq` and `yq` are essential for manipulating JSON/YAML in shell scripts, but ensure scripts handle YAML-in-YAML strings (like Istio's ConfigMap) correctly.

## 4. Environment Checklist
- **Context**: `kubectl config use-context colima`
- **Port 81**: Istio Ingress Gateway (SSO App)
- **Port 82**: Nginx Ingress (Simple App)
- **Domain**: `localhost` (No `/etc/hosts` required)
