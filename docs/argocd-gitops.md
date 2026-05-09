# Argo CD GitOps on Azure

ShopVerse uses GitOps deployment with Argo CD and Helm on Azure Kubernetes Service (AKS).

## Environment Mapping

| Branch | Environment | Namespace | Argo CD app | Values file | Terraform DB/secrets state |
| ------ | ----------- | --------- | ----------- | ----------- | -------------------------- |
| `develop` | dev | `shopverse-dev` | `shopverse-dev` | `helm/shopverse/values-dev.yaml` | `db/dev` |
| `staging` | staging | `shopverse-staging` | `shopverse-staging` | `helm/shopverse/values-staging.yaml` | `db/staging` |
| `main` | prod | `shopverse` | `shopverse` | `helm/shopverse/values-prod.yaml` | `db/prod` |

## Flow

```text
push to develop/staging/main
  -> GitHub Actions tests, scans, builds, and pushes images to Azure Container Registry (ACR)
  -> Terraform provisions or updates the shared Azure core stack
  -> Terraform provisions or updates the branch environment Azure MySQL Flexible Server and Key Vault stack
  -> GitHub Actions stores JWT_SECRET in Azure Key Vault
  -> GitHub Actions commits the selected values file with image, database, and Key Vault outputs
  -> Argo CD syncs the Helm chart from Git
  -> Key Vault CSI Driver creates or updates shopverse-secret from Azure Key Vault
  -> AKS rolls frontend/backend pods to the new ACR image tags
```

## Required GitHub Secrets

```text
AZURE_CLIENT_ID
AZURE_TENANT_ID
AZURE_SUBSCRIPTION_ID
AZURE_LOCATION
AKS_CLUSTER_NAME
TF_STATE_STORAGE_ACCOUNT
TF_STATE_CONTAINER
JWT_SECRET
ARGOCD_REPO_USERNAME
ARGOCD_REPO_TOKEN
```

`ARGOCD_REPO_USERNAME` and `ARGOCD_REPO_TOKEN` are only required for private
repositories.

## Validation

```bash
kubectl get application -n argocd
kubectl get pods -n shopverse-dev
kubectl get secretproviderclass shopverse-secrets -n shopverse-dev
kubectl get secret shopverse-secret -n shopverse-dev
kubectl get ingress -n shopverse-dev
```

`shopverse-secret` is managed by Azure Key Vault Secrets Store CSI Driver. Do not create it manually with
`kubectl create secret`; update Azure Key Vault instead and restart backend Pods
when rotated values must be loaded into environment variables.
