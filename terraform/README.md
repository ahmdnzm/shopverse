# ShopVerse Infrastructure

ShopVerse infrastructure is managed via Terraform and is split into a shared 
core stack and per-environment RDS/Secrets stacks.

## Stacks

| Stack | Path | Backend Key | Resources |
| ----- | ---- | ----------- | --------- |
| Shared core | `terraform/core` | `core` | VPC, EKS, ECR, Route 53, IAM OIDC Federation, Managed Prometheus |
| Dev RDS/secrets | `terraform/env-rds` | `rds.dev` | `shopverse-dev-mysql`, Secrets Manager, IAM Roles for IRSA, CloudFront |
| Staging RDS/secrets | `terraform/env-rds` | `rds.staging` | `shopverse-staging-mysql`, Secrets Manager, IAM Roles for IRSA, CloudFront |
| Prod RDS/secrets | `terraform/env-rds` | `rds.prod` | `shopverse-prod-mysql`, Secrets Manager, IAM Roles for IRSA, CloudFront |

All application environments share the same EKS cluster. Each environment has
its own private Amazon RDS instance, AWS Secrets Manager secrets, and CloudFront distribution.

## Backend Setup

Create an S3 bucket for Terraform state:

```bash
aws s3api create-bucket --bucket shopverse-tfstate --region ap-southeast-1 --create-bucket-configuration LocationConstraint=ap-southeast-1
```

## Shared Core

Provision the shared VPC, EKS cluster, ECR repositories, Route 53 zone, and IAM OIDC Federation:

```bash
terraform -chdir=terraform/core init \
  -backend-config="bucket=shopverse-tfstate" \
  -backend-config="key=core" \
  -backend-config="region=ap-southeast-1"

terraform -chdir=terraform/core apply \
  -var="aws_region=ap-southeast-1" \
  -var="github_repository=<owner>/<repo>"
```

Connect kubectl:

```bash
aws eks update-kubeconfig --region ap-southeast-1 --name shopverse-cluster
```

## Environment RDS, Secrets & CloudFront

Provision the RDS instance, Secrets Manager secrets, and CloudFront distribution for an environment. 
The GitHub Actions workflow does this automatically.

```bash
# dev
terraform -chdir=terraform/env-rds init \
  -backend-config="bucket=shopverse-tfstate" \
  -backend-config="key=rds.dev" \
  -backend-config="region=ap-southeast-1" \
  -reconfigure

terraform -chdir=terraform/env-rds apply \
  -var="aws_region=ap-southeast-1" \
  -var="project_name=shopverse" \
  -var="environment=dev" \
  -var="tf_state_bucket=shopverse-tfstate" \
  -var="alb_dns_name=<alb-dns-name>"
```

## GitOps Deployment

The workflow authenticates to AWS using IAM OIDC, builds and pushes images to ECR, 
provisions the environment stack, stores `JWT_SECRET` in Secrets Manager, updates 
Helm values, and lets Argo CD sync the app. The Helm release creates a
`SecretProviderClass` so EKS syncs `shopverse-secret` from Secrets Manager using the AWS provider.

## Disaster Recovery

Amazon RDS Multi-AZ protects production against zonal failure inside the
selected region. It is not a complete multi-region disaster recovery design.
