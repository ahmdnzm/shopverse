# ShopVerse - Full-Stack E-Commerce Application

A production-ready 3-tier e-commerce web application built with React, Go
(Fiber), and Azure Database for MySQL, deployed on Microsoft Azure using AKS,
Helm charts, Argo CD, and Terraform.

## Architecture:

```text
                    +------------------------------------+
                    |           User / Browser           |
                    +----------------+-------------------+
                                     |
                                     v
                    +------------------------------------+
                    |             Azure DNS              |
                    | dev / staging / prod hostnames     |
                    +----------------+-------------------+
                                     |
                                     v
                    +------------------------------------+
                    | Azure Front Door & App Gateway     |
                    | TLS Cert + WAF + CDN for /*        |
                    +----------------+-------------------+
                                     |
                    +----------------v-------------------+
                    |  AGIC Ingress Controller           |
                    |  routes traffic to AKS pods        |
                    +--------+-------------------+-------+
                             |                   |
                   /api/* + /health          /* routes
                    no CDN cache        frontend CDN cache
                             |                   |
                    +--------v---------+   +-----v----------------+
                    | Backend Service  |   | Frontend Service     |
                    | (Go + Fiber)     |   | (React + Nginx)      |
                    | Port 8080 + NEG  |   | Port 80 + NEG        |
                    | HPA (2-10 repls) |   | HPA (2-5 repls)      |
                    | PDB + NetPolicy  |   | PDB + NetPolicy      |
                    +--------+---------+   +----------------------+
                             |
                   DB_HOST + DB_USER
                   DB_PASSWORD from secret
                             |
                    +--------v---------+
                    | Azure DB for MySQL|
                    | Private IP       |
                    | Backups + HA     |
                    +------------------+

                    +------------------+
                    | Azure Key Vault  |
                    | DB + JWT secrets |
                    +--------+---------+
                             |
                             v
                    +------------------+
                    | Key Vault Provider|
                    | Class (CSI Driver)|
                    +--------+---------+
                             |
                             v
                    +------------------+
                    | Kubernetes Secret|
                    | shopverse-secret |
                    +------------------+
                             |
                    DB_PASSWORD + JWT_SECRET
                             |
                             v
                    Backend environment vars

                    +-------------------------------+
                    | Azure Monitor Observability   |
                    | Log Analytics + App Insights  |
                    | Azure Managed Prometheus      |
                    | Dashboards + alerts           |
                    | Grafana-compatible PromQL     |
                    +-------------------------------+
                         ^          ^          ^
                         |          |          |
                    JSON logs   /metrics   OTEL traces
                    backend +   internal   backend + DB
                    Nginx       scrape
```

- The frontend currently runs in AKS with Nginx because Nginx provides SPA fallback and proxies `/api/` to the backend service.
- Azure Application Gateway Ingress Controller (AGIC) manages public traffic, TLS, and WAF.
- **Horizontal Pod Autoscaler (HPA)** dynamically scales pods based on CPU load.
- **PodDisruptionBudget (PDB)** ensures high availability during maintenance.
- **NetworkPolicies** enforce zero-trust security by restricting pod-to-pod communication.
- Azure Key Vault is the source of truth for `DB_PASSWORD` and `JWT_SECRET`.
- The Secrets Store CSI Driver syncs Key Vault secrets into the runtime Kubernetes `shopverse-secret`.
- Azure Database for MySQL Flexible Server provides the relational data store with HA and private networking.
- Azure Monitor (Log Analytics, App Insights, Managed Prometheus) provides full observability.

## Tech Stack

| Layer    | Technology                                                                                                                                                                                                     |
| -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Frontend | React 18, TailwindCSS, Vite                                                                                                                                                                                    |
| Backend  | Go 1.24, Fiber, GORM, JWT                                                                                                                                                                                      |
| Database | Azure Database for MySQL Flexible Server 8.0                                                                                                                                                                    |
| Infra    | AKS, Azure Container Registry (ACR), Application Gateway (AGIC), Azure DNS, Azure WAF, Azure Key Vault, Log Analytics, Application Insights, Managed Prometheus, Terraform                                     |
| CI/CD    | GitHub Actions, Argo CD, Helm, Trivy                                                                                                                                                                           |
| IaC      | Terraform Stacks (`core`, `env-db`)                                                                                                                                                                            |


## API Endpoints

| Method | Endpoint           | Auth          | Description                                                    |
| ------ | ------------------ | ------------- | -------------------------------------------------------------- |
| POST   | /api/auth/register | No            | Register new user                                              |
| POST   | /api/auth/login    | No            | Login, returns JWT                                             |
| GET    | /api/products      | No            | List products                                                  |
| GET    | /api/products/:id  | No            | Get single product                                             |
| POST   | /api/products      | JWT           | Create product (admin)                                         |
| GET    | /api/cart          | JWT           | Get user's cart                                                |
| POST   | /api/cart          | JWT           | Add item to cart                                               |
| PUT    | /api/cart/:id      | JWT           | Update cart item qty                                           |
| DELETE | /api/cart/:id      | JWT           | Remove cart item                                               |
| GET    | /api/orders        | JWT           | Get user's orders                                              |
| POST   | /api/orders        | JWT           | Place order from cart                                          |
| GET    | /health            | No            | Health check                                                   |
| GET    | /metrics           | Internal only | Prometheus scrape endpoint; not exposed through public Ingress |


---

## Local Development

### Prerequisites

- Docker & Docker Compose
- Node.js 18+ (for frontend dev)
- Go 1.24+ (for backend dev)

### Quick Start with Docker Compose

```bash
# Clone the repo
git clone <repo-url> && cd shopverse

# Start all services
docker-compose up --build

# Access the app
# Frontend: http://localhost:3000
# Backend:  http://localhost:8080
```

---

## Azure Deployment (Step-by-Step from Local)

### Prerequisites

Install the following tools on your local machine:

| Tool       | Version  | Download                                                                                                   |
| ---------- | -------- | ---------------------------------------------------------------------------------------------------------- |
| Terraform  | >= 1.5.0 | [https://developer.hashicorp.com/terraform/downloads](https://developer.hashicorp.com/terraform/downloads) |
| Azure CLI  | Latest   | [https://learn.microsoft.com/en-us/cli/azure/install-azure-cli](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) |
| kubectl    | Latest   | [https://kubernetes.io/docs/tasks/tools/](https://kubernetes.io/docs/tasks/tools/)                         |
| Helm 3     | Latest   | [https://helm.sh/docs/intro/install/](https://helm.sh/docs/intro/install/)                                 |
| Docker     | Latest   | [https://docs.docker.com/get-docker/](https://docs.docker.com/get-docker/)                                 |

---

### Step 1: Configure Azure CLI

```bash
az login
az account set --subscription <subscription-id>

# Verify your identity
az account show
```

---

### Step 2: Create Azure Infrastructure using Terraform

Terraform is split into shared core infrastructure and per-environment database/secrets:

- `terraform/core`: Resource Group, VNet, AKS, ACR, Azure DNS, Public IPs, WAF, Log Analytics, App Insights, Managed Prometheus, and GitHub OIDC Federation.
- `terraform/env-db`: Azure Database for MySQL Flexible Server, Key Vault secrets, and Role Assignments per environment.

See [terraform/README.md](terraform/README.md) for detailed Terraform instructions.

```bash
# Initialize and apply shared core
terraform -chdir=terraform/core init \
  -backend-config="resource_group_name=<rg>" \
  -backend-config="storage_account_name=<storage>" \
  -backend-config="container_name=<container>" \
  -backend-config="key=core.terraform.tfstate"

terraform -chdir=terraform/core apply \
  -var="resource_group_name=shopverse-rg" \
  -var="location=southeastasia" \
  -var="github_repository=<owner>/<repo>"
```

The CI/CD workflow provisions `terraform/env-db` for the branch being deployed.

Add the following values as GitHub Actions secrets:

| Secret | Value |
| --- | --- |
| `AZURE_CLIENT_ID` | `github_actions_client_id` Terraform output |
| `AZURE_TENANT_ID` | `tenant_id` Terraform output |
| `AZURE_SUBSCRIPTION_ID` | `subscription_id` Terraform output |
| `RESOURCE_GROUP` | `shopverse-rg` |
| `LOCATION` | `southeastasia` |
| `TF_STATE_STORAGE_ACCOUNT` | Your storage account for TF state |
| `TF_STATE_CONTAINER` | Your container for TF state |
| `JWT_SECRET` | Application JWT signing secret |

---

### Step 3: Connect to the AKS Cluster

```bash
az aks get-credentials --resource-group shopverse-rg --name shopverse-cluster

# Verify connection
kubectl get nodes
```

---

### Step 4: Build, Tag & Push Docker Images

The shared core Terraform stack creates the Azure Container Registry (ACR):

```bash
az acr login --name shopverseregistry
```

Build and push images:

```bash
ACR=shopverseregistry.azurecr.io
TAG=manual-$(date +%Y%m%d%H%M%S)

docker build -t ${ACR}/shopverse-frontend:${TAG} ./frontend
docker build -t ${ACR}/shopverse-backend:${TAG} ./backend

docker push ${ACR}/shopverse-frontend:${TAG}
docker push ${ACR}/shopverse-backend:${TAG}
```

---

### Step 5: Deploy with GitHub Actions and Argo CD

Push to one of the deployment branches:

```bash
git push origin develop
```

The workflow will:

1. Run backend and frontend checks.
2. Build and scan frontend/backend images.
3. Push images to ACR.
4. Provision or update the active environment MySQL stack.
5. Store the active `JWT_SECRET` value in Azure Key Vault.
6. Update the matching Helm values file with image, database, and Key Vault outputs.
7. Apply the Argo CD application and let Argo CD sync the release.
8. Let Secrets Store CSI Driver create or update `shopverse-secret` from Key Vault.

---

### Step 6: Verify the Deployment

```bash
kubectl get application -n argocd
kubectl get pods -n shopverse-dev
kubectl get secretproviderclass shopverse-secrets -n shopverse-dev
kubectl get secret shopverse-secret -n shopverse-dev
kubectl get ingress -n shopverse-dev
```

---

### Step 7: DNS

If the parent domain is not already delegated to the Azure DNS zone, update the
parent registrar with the `dns_name_servers` Terraform output.
