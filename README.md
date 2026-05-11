# ShopVerse - Full-Stack E-Commerce Application

A production-ready 3-tier e-commerce web application built with React, Go
(Fiber), and Amazon RDS for MySQL, deployed on Amazon Web Services (AWS) using 
EKS, Helm charts, Argo CD, and Terraform.

## Architecture:

```text
                    +------------------------------------+
                    |           User / Browser           |
                    +----------------+-------------------+
                                     |
                                     v
                    +------------------------------------+
                    |             Route 53               |
                    | dev / staging / prod hostnames     |
                    +----------------+-------------------+
                                     |
                                     v
                    +------------------------------------+
                    |        Amazon CloudFront           |
                    |   Global CDN + WAF + TLS Edge      |
                    +----------------+-------------------+
                                     |
                                     v
                    +------------------------------------+
                    |    Application Load Balancer       |
                    |  Regional Traffic Orchestration    |
                    +----------------+-------------------+
                                     |
                    +----------------v-------------------+
                    |   AWS Load Balancer Controller     |
                    |  routes traffic to EKS pods        |
                    +--------+-------------------+-------+
                             |                   |
                   /api/* + /health          /* routes
                    no CDN cache        frontend CDN cache
                             |                   |
                    +--------v---------+   +-----v----------------+
                    | Backend Service  |   | Frontend Service     |
                    | (Go + Fiber)     |   | (React + Nginx)      |
                    | Port 8080        |   | Port 80              |
                    | HPA (2-10 repls) |   | HPA (2-5 repls)      |
                    | PDB + NetPolicy  |   | PDB + NetPolicy      |
                    +--------+---------+   +----------------------+
                             |
                   DB_HOST + DB_USER
                   DB_PASSWORD from secret
                             |
                    +--------v---------+
                    | Amazon RDS MySQL |
                    | Private Subnet   |
                    | Backups + Multi-AZ|
                    +------------------+

                    +------------------+
                    | AWS Secrets Mgr  |
                    | DB + JWT secrets |
                    +--------+---------+
                             |
                             v
                    +------------------+
                    | Secrets Store CSI|
                    | Driver (AWS Prov)|
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
                    |   AWS Observability Stack     |
                    | CloudWatch Logs + Metrics     |
                    | Amazon Managed Prometheus     |
                    | Dashboards + alerts           |
                    +-------------------------------+
                         ^          ^          ^
                         |          |          |
                    JSON logs   /metrics   OTEL traces
                    backend +   internal   backend + DB
                    Nginx       scrape
```

- The frontend currently runs in EKS with Nginx because Nginx provides SPA fallback and proxies `/api/` to the backend service.
- AWS Load Balancer Controller manages public traffic, TLS, and WAF through an Application Load Balancer (ALB).
- **Horizontal Pod Autoscaler (HPA)** dynamically scales pods based on CPU load.
- **PodDisruptionBudget (PDB)** ensures high availability during maintenance.
- **NetworkPolicies** enforce zero-trust security by restricting pod-to-pod communication.
- AWS Secrets Manager is the source of truth for `DB_PASSWORD` and `JWT_SECRET`.
- The Secrets Store CSI Driver (AWS Provider) syncs Secrets Manager secrets into the runtime Kubernetes `shopverse-secret`.
- Amazon RDS for MySQL provides the relational data store with Multi-AZ HA and private networking.
- CloudWatch and Amazon Managed Prometheus provide full observability.

## Tech Stack

| Layer    | Technology                                                                                                                                                                                                     |
| -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Frontend | React 18, TailwindCSS, Vite                                                                                                                                                                                    |
| Backend  | Go 1.24, Fiber, GORM, JWT                                                                                                                                                                                      |
| Database | Amazon RDS for MySQL 8.0                                                                                                                                                                                       |
| Infra    | EKS, Amazon ECR, ALB, Route 53, AWS WAF, Secrets Manager, CloudWatch, Amazon Managed Prometheus, Terraform                                                                                                     |
| CI/CD    | GitHub Actions, Argo CD, Helm, Trivy                                                                                                                                                                           |
| IaC      | Terraform Stacks (`core`, `env-rds`)                                                                                                                                                                           |


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

## Deployment (Step-by-Step from Local)

### Prerequisites

Install the following tools on your local machine:

| Tool       | Version  | Download                                                                                                   |
| ---------- | -------- | ---------------------------------------------------------------------------------------------------------- |
| Terraform  | >= 1.5.0 | [https://developer.hashicorp.com/terraform/downloads](https://developer.hashicorp.com/terraform/downloads) |
| AWS CLI    | Latest   | [https://aws.amazon.com/cli/](https://aws.amazon.com/cli/)                                                 |
| kubectl    | Latest   | [https://kubernetes.io/docs/tasks/tools/](https://kubernetes.io/docs/tasks/tools/)                         |
| Helm 3     | Latest   | [https://helm.sh/docs/intro/install/](https://helm.sh/docs/intro/install/)                                 |
| Docker     | Latest   | [https://docs.docker.com/get-docker/](https://docs.docker.com/get-docker/)                                 |

---

### Step 1: Configure AWS CLI

```bash
aws configure
# or use SSO
aws sso login
```

---

### Step 2: Create Infrastructure using Terraform

Terraform is split into shared core infrastructure and per-environment database/secrets:

- `terraform/core`: VPC, EKS, ECR, Route 53, and GitHub IAM OIDC Federation.
- `terraform/env-rds`: Amazon RDS for MySQL and Secrets Manager secrets per environment.

See [terraform/README.md](terraform/README.md) for detailed Terraform instructions.

```bash
# Initialize and apply shared core
terraform -chdir=terraform/core init \
  -backend-config="bucket=<bucket>" \
  -backend-config="key=core" \
  -backend-config="region=<region>"

terraform -chdir=terraform/core apply \
  -var="aws_region=ap-southeast-1" \
  -var="github_repository=<owner>/<repo>"
```

The CI/CD workflow provisions `terraform/env-rds` for the branch being deployed.

Add the following values as GitHub Actions secrets:

| Secret | Value |
| --- | --- |
| `AWS_GITHUB_ROLE_ARN` | `github_actions_role_arn` Terraform output |
| `AWS_REGION` | e.g., `ap-southeast-1` |
| `TF_STATE_BUCKET` | Your S3 bucket for TF state |
| `JWT_SECRET` | Application JWT signing secret |

---

### Step 3: Connect to the EKS Cluster

```bash
aws eks update-kubeconfig --region ap-southeast-1 --name shopverse-cluster

# Verify connection
kubectl get nodes
```

---

### Step 4: Build, Tag & Push Docker Images

The shared core Terraform stack creates the Amazon ECR repositories:

```bash
aws ecr get-login-password --region ap-southeast-1 | docker login --username AWS --password-stdin <aws_account_id>.dkr.ecr.ap-southeast-1.amazonaws.com
```

Build and push images:

```bash
REGISTRY=<aws_account_id>.dkr.ecr.ap-southeast-1.amazonaws.com
TAG=manual-$(date +%Y%m%d%H%M%S)

docker build -t ${REGISTRY}/shopverse-frontend:${TAG} ./frontend
docker build -t ${REGISTRY}/shopverse-backend:${TAG} ./backend

docker push ${REGISTRY}/shopverse-frontend:${TAG}
docker push ${REGISTRY}/shopverse-backend:${TAG}
```

---

### Step 5: Deploy with GitHub Actions and Argo CD

The `terraform/core` stack automatically installs Argo CD, the AWS Load Balancer Controller, the Secrets Store CSI Driver, and CloudWatch Observability.

Push to one of the deployment branches:

```bash
git push origin develop
```

The workflow will:

1. Run backend and frontend checks.
2. Build and scan frontend/backend images.
3. Push images to ECR.
4. Provision or update the active environment RDS stack.
5. Store the active `JWT_SECRET` value in AWS Secrets Manager.
6. Update the matching Helm values file with image, database, and Secrets Manager outputs.
7. Apply the Argo CD application and let Argo CD sync the release.
8. Let Secrets Store CSI Driver create or update `shopverse-secret` from Secrets Manager.

---

### Step 6: Verify the Deployment

```bash
kubectl get application -n argocd
kubectl get pods -n shopverse-dev
kubectl get secretproviderclass shopverse-secrets -n shopverse-dev
kubectl get secret shopverse-secret -n shopverse-dev
kubectl get ingress -n shopverse-dev
```
