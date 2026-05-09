# ShopVerse - Production-Ready Multi-Cloud E-Commerce

ShopVerse is a scalable, cloud-native e-commerce platform designed for high availability and performance across both **Amazon Web Services (AWS)** and **Microsoft Azure**.

## 🚀 Key Features

- **Multi-Cloud Architecture**: Native support for AWS (EKS, RDS) and Azure (AKS, Azure Database for MySQL).
- **Production-Ready**: High Availability (HA) configurations, auto-scaling, and managed database services.
- **Infrastructure as Code (IaC)**: Fully automated infrastructure provisioning using Terraform.
- **GitOps Continuous Delivery**: Automated deployments using ArgoCD and Helm.
- **Observability**: Built-in support for distributed tracing, metrics, and structured logging.
- **Zero-Trust Security**: Network policies, secret management (AWS Secrets Manager / Azure Key Vault), and encrypted communication.

## 🏗️ Architecture

ShopVerse follows a microservices architecture, containerized with Docker and orchestrated by Kubernetes.

### Cloud Native Components

| Component | AWS Implementation | Azure Implementation |
|-----------|--------------------|----------------------|
| **Kubernetes** | Amazon EKS | Azure Kubernetes Service (AKS) |
| **Database** | Amazon RDS for MySQL | Azure Database for MySQL |
| **Ingress** | AWS Load Balancer Controller | Application Gateway Ingress Controller (AGIC) |
| **Secrets** | AWS Secrets Manager | Azure Key Vault |
| **Registry** | Amazon ECR | Azure Container Registry (ACR) |
| **DNS/CDN** | Route 53 / CloudFront | Azure DNS / Front Door |

## 🛠️ Tech Stack

- **Frontend**: React 18, TailwindCSS, Vite.
- **Backend**: Go 1.24, Fiber Framework, GORM.
- **Database**: MySQL 8.0.
- **Orchestration**: Kubernetes, Helm 3.
- **Infrastructure**: Terraform, Docker.

## 📂 Project Structure

```text
.
├── argocd/           # GitOps Application manifests
├── backend/          # Go microservice source code
├── frontend/         # React SPA source code
├── helm/             # Unified Helm charts for K8s deployment
├── terraform/        # Infrastructure as Code
│   ├── modules/      # Reusable cloud modules (VPC, EKS, RDS, etc.)
│   ├── core/         # Shared infrastructure (Clusters, Network)
│   └── env-db/       # Environment-specific database & secrets
└── docs/             # Architecture diagrams and documentation
```

## 💻 Local Development

Run the entire stack locally using Docker Compose:

```bash
docker-compose up --build
```

Access the application:
- **Frontend**: `http://localhost:3000`
- **Backend**: `http://localhost:8080`

## ☁️ Deployment

Detailed deployment guides are available in the `docs/` and `terraform/` directories:
- [Azure Deployment Guide](docs/azure-architecture.md)
- [AWS Deployment Guide](terraform/README.md)
