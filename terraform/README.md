# ShopVerse Terraform Infrastructure

ShopVerse Terraform is split into shared Azure infrastructure and per-environment
Azure Database for MySQL Flexible Server and Azure Key Vault stacks.

## Stacks

| Stack | Path | Backend prefix | Resources |
| ----- | ---- | -------------- | --------- |
| Shared core | `terraform/core` | `core.terraform.tfstate` | VNet, AKS with Key Vault CSI Driver, Azure Managed Prometheus, Azure Monitor (Log Analytics, App Insights), Azure Container Registry (ACR), Azure DNS, Application Gateway (AGIC), Azure WAF, Entra ID Workload Identity |
| Dev DB/secrets | `terraform/env-db` | `db.dev.terraform.tfstate` | `shopverse-dev-mysql`, Key Vault secrets, Managed Identity Role Assignments |
| Staging DB/secrets | `terraform/env-db` | `db.staging.terraform.tfstate` | `shopverse-staging-mysql`, Key Vault secrets, Managed Identity Role Assignments |
| Prod DB/secrets | `terraform/env-db` | `db.prod.terraform.tfstate` | `shopverse-prod-mysql`, Key Vault secrets, Managed Identity Role Assignments |

All app environments share the same AKS cluster. Each environment has
its own private Azure Database for MySQL Flexible Server and Azure Key Vault.

## Backend Setup

Create the Azure Storage Account state container once:

```bash
az group create --name shopverse-tfstate-rg --location southeastasia

az storage account create --name shopversetfstate \
  --resource-group shopverse-tfstate-rg \
  --location southeastasia \
  --sku Standard_LRS

az storage container create --name tfstate --account-name shopversetfstate
```

## Shared Core

Provision the shared VNet, AKS cluster with Key Vault integration
and CSI Driver enabled, Azure Monitor resources, Azure Container Registry, 
Azure DNS zone, Application Gateway, Azure WAF policy, and Entra ID OIDC Federation:

```bash
terraform -chdir=terraform/core init \
  -backend-config="resource_group_name=shopverse-tfstate-rg" \
  -backend-config="storage_account_name=shopversetfstate" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=core.terraform.tfstate"

terraform -chdir=terraform/core apply \
  -var="resource_group_name=shopverse-rg" \
  -var="location=southeastasia" \
  -var="github_repository=<owner>/<repo>"
```

Connect kubectl:

```bash
az aks get-credentials --resource-group shopverse-rg --name shopverse-cluster
```

## Environment MySQL And Secrets

Provision one MySQL and Key Vault stack per environment. The GitHub
Actions workflow does this automatically for the branch being deployed.

```bash
# dev
terraform -chdir=terraform/env-db init \
  -backend-config="resource_group_name=shopverse-tfstate-rg" \
  -backend-config="storage_account_name=shopversetfstate" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=db.dev.terraform.tfstate" \
  -reconfigure

terraform -chdir=terraform/env-db apply \
  -var="resource_group_name=shopverse-rg" \
  -var="location=southeastasia" \
  -var="project_name=shopverse" \
  -var="environment=dev" \
  -var="tf_state_storage_account=shopversetfstate" \
  -var="tf_state_container=tfstate" \
  -var="key_vault_name=shopverse-dev-kv"
```

## GitOps Deployment

The workflow authenticates to Azure using OIDC, builds and pushes images to ACR, 
provisions the environment stack, stores `JWT_SECRET` in Key Vault, updates 
Helm values, and lets Argo CD sync the app. The Helm release creates a
`SecretProviderClass` so AKS syncs `shopverse-secret` from Key Vault. 

## Disaster Recovery

Azure MySQL regional HA protects production against zonal failure inside the
selected region. It is not a complete multi-region disaster recovery design.
