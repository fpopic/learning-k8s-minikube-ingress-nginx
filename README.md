# learning-minikube-ingress-nginx

## How to run

Environment
- m1 macOs
- minikube version: v1.27.0

### 1. Build Docker images for Minikube

Since we are using local images, you must build them directly in the Minikube Docker daemon so that the cluster can find them:

```bash
# Point your shell to Minikube's Docker daemon
eval $(minikube -p minikube docker-env)

# Build the API image
docker build -t hello-api:latest ./api
```

### 2. Start Minikube & Apply Manifests

Run the startup script to spin up the cluster, enable the ingress addon, and apply all resources:

```bash
./minikube-up.sh
```

To stop and clean up everything:

```bash
./minikube-down.sh
```

## Key Concepts

To understand how these pieces fit together, here is the purpose of each resource in the `k8s/` directory:

### 1. Namespace (`1.namespace.yaml`)
- **Purpose**: Creates a logical "box" to isolate your application. 

### 2. UI Deployment (`2.ui-deployment.yaml`)
- **Purpose**: Manages the lifecycle of your **Pods** (the actual containers running your code). It ensures the desired number of containers are running and handles updates/rollbacks.
- **Key Part**: The `template` section defines what the Pod looks like, and the `labels` allow others to find it.

### 3. UI Service (`3.ui-service.yaml`)
- **Purpose**: Provides a **stable entry point** (IP/DNS name) for a group of Pods. Since Pods can die and restart with new IPs, the Service acts as a permanent "front door."
- **How it works**: It uses a **Selector** (e.g., `app: ui`) to find and load-balance traffic across all Pods that have the matching label.

### 4. API Deployment (`4.api-deployment.yaml`)
- **Purpose**: Runs the modern Dockerized FastAPI application.
- **Key Part**: Uses `imagePullPolicy: Never` to use the local image we built in Step 1.

### 5. API Service (`5.api-service.yaml`)
- **Purpose**: An internal `ClusterIP` Service that exposes the API within the cluster.

### 6. Ingress (`6.ingress-resource.yaml`)
- **Purpose**: Acts as the **Smart Gateway** (L7 Load Balancer) that allows external traffic from the internet into your cluster.
- **Features**: It handles domain-based routing (e.g., `my-web.com`), SSL/TLS termination, and path-based routing:
  - `my-web.com/api/*` → `svc-api`
  - `my-web.com/*` → `svc-ui`

### The "Glue": Labels & Selectors
- **Labels** are key-value pairs (like `app: ui`) attached to resources like Pods.
- **Selectors** are "search queries" used by Deployments and Services to find those labeled Pods.
- **Connection Rule**: For a Service to talk to a Pod, the Service's `selector` **must** match the Pod's `label`.

## Extensions: FastAPI API

We extended the setup with a simple FastAPI application to demonstrate path-based routing in the Ingress.

- **`api/Dockerfile`**: A modern Docker image using **`uv`** (a high-performance Rust-based Python package manager) for near-instant dependency resolution and installation.

**Available Endpoints**:
- `http://my-web.com/api/users`
- `http://my-web.com/api/payments`

## Learning resources

Ingress learning resources
- https://kubernetes.io/docs/tasks/access-application-cluster/ingress-minikube/
- https://cloud.google.com/kubernetes-engine/docs/tutorials/http-balancer#deploying_a_web_application
- https://www.youtube.com/watch?v=GhZi4DxaxxE&ab_channel=KodeKloud

Minikube learning resources
- https://minikube.sigs.k8s.io/docs/handbook/addons/ingress-dns/
- https://medium.com/@Oskarr3/setting-up-ingress-on-minikube-6ae825e98f82#:~:text=any%20other.-,Setup,-Minikube%20v0.14.0%20(and
