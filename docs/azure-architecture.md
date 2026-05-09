# ShopVerse on Azure

ShopVerse runs on Azure Kubernetes Service (AKS) with one shared cluster and separate namespaces
for dev, staging, and prod.

## Public Traffic

Azure Application Gateway Ingress Controller (AGIC) provisions Azure Application Gateway
resources. Azure WAF and the Azure-managed certificates are configured on that load balancer 
layer through Ingress annotations and Azure Key Vault. Nginx only runs inside the frontend 
Pods to serve the React build, provide SPA fallback, and proxy `/api/` to the backend service.
Each environment uses:

| Environment | Hostname | Static IP resource |
| ----------- | -------- | ------------------ |
| dev | `dev.shopverse.ahmdnzm.com` | App Gateway Public IP |
| staging | `staging.shopverse.ahmdnzm.com` | App Gateway Public IP |
| prod | `shopverse.ahmdnzm.com` | App Gateway Public IP |

The Helm chart creates:

- `SecretProviderClass` for Azure Key Vault secrets (CSI Driver).
- AGIC Ingress annotations for health checks and Azure WAF.
- One Ingress routing `/api` and `/health` to the backend and `/` to the
  frontend.

Azure Front Door (optional) can be added for CDN/Global load balancing, but currently,
ShopVerse uses Application Gateway for regional traffic management.

## Data Plane

The backend connects to Azure Database for MySQL Flexible Server over private IP using the existing
environment variables:

```text
DB_HOST
DB_PORT
DB_NAME
DB_USER
DB_PASSWORD
DB_TLS
JWT_SECRET
FRONTEND_ORIGIN
```

Each environment has its own MySQL Flexible Server instance, generated database password,
and JWT secret resource in Azure Key Vault. GitHub Actions writes the active
JWT value into Key Vault and commits the secret identifiers into the environment Helm values.

The Secrets Store CSI Driver keeps `shopverse-secret` populated from Azure Key Vault:

```text
Azure Key Vault
  -> SecretProviderClass (provider: azure)
  -> CSI Driver
  -> Kubernetes Secret: shopverse-secret
  -> backend env vars: DB_PASSWORD, JWT_SECRET
```

Azure Key Vault is the source of truth for generated database passwords, JWT
secrets, and third-party credentials. Kubernetes Secrets are runtime delivery
objects for Pods, not the long-term secrets management system. Because the
backend reads these values as environment variables, Pods must restart to pick
up rotated secret values.

## Security

- **NetworkPolicies:** Zero-trust communication is enforced. Ingress is denied by default; only the Application Gateway can talk to the Frontend, and only the Frontend can talk to the Backend.
- **Azure WAF:** Attached through Ingress annotations managed by AGIC, operating in Prevention mode with custom rate limiting.
- **AKS Security:** The cluster is configured with 3 nodes for high availability and uses system-assigned managed identities.
- **Secrets Management:** Azure Key Vault CSI Driver delivers Key Vault values into the runtime `shopverse-secret` Kubernetes Secret.
- **Identity:** GitHub Actions uses OpenID Connect (OIDC) for Workload Identity Federation.
- **Vulnerability Scanning:** Container images are scanned by Trivy in the CI/CD pipeline.

## Delivery

GitHub Actions builds and scans frontend/backend images, pushes them to ACR, provisions the environment-specific infrastructure, and updates GitOps values. Argo CD then synchronizes the Helm releases into AKS.

### Production Hardening
The production environment includes:
- **Horizontal Pod Autoscaling (HPA):** Automatically scales Pods based on CPU utilization (up to 10 for backend, 5 for frontend).
- **PodDisruptionBudgets (PDB):** Ensures high availability during maintenance by maintaining a minimum number of available replicas.
- **Probes:** Configured readiness and liveness probes for all components.
- **Resource Limits:** CPU and Memory limits/requests are defined for all containers.

## Observability

ShopVerse uses Azure Monitor as the primary production visibility layer. 
The shared Terraform core enables Log Analytics, Container Insights, 
Managed Prometheus, and Application Insights.

Backend logs are structured JSON written to stdout so Log Analytics can parse
and search fields. The frontend Nginx container also writes JSON access logs to 
stdout.

The Go/Fiber backend exposes `GET /metrics` for in-cluster scraping only. 
Managed Prometheus scrapes the backend's internal-only `/metrics` endpoint 
through the chart's configuration. Backend metrics include request count, 
request duration, in-flight requests, and database connection pool statistics. 

The backend initializes OpenTelemetry tracing and propagates W3C `traceparent`
and `tracestate` headers. Spans are exported to Application Insights.

Dashboards and alert policies are managed in Terraform.
