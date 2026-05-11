# Shopverse: Azure Infrastructure Setup Guide (Manual via Console)

This guide provides step-by-step instructions to manually provision the complete Azure infrastructure for Shopverse via the Azure Portal, based on the project's architecture.

## 1. Resource Group
1. Log in to the [Azure Portal](https://portal.azure.com/).
2. Search for **Resource groups** and click **+ Create**.
3. Set **Resource group** to `shopverse-rg` and choose a **Region** (e.g., `East US`).
4. Click **Review + create**, then **Create**.

## 2. Virtual Network (VNet) & Subnets
1. Search for **Virtual networks** and click **+ Create**.
2. **Basics:** Resource Group: `shopverse-rg`, Name: `shopverse-vnet`.
3. **IP Addresses:** 
   - Set address space (e.g., `10.0.0.0/16`).
   - Add subnets: 
     - `aks-subnet` (e.g., `10.0.1.0/24`) for Kubernetes nodes.
     - `db-subnet` (e.g., `10.0.2.0/24`), delegated to `Microsoft.DBforMySQL/flexibleServers`.
     - `appgw-subnet` (e.g., `10.0.3.0/24`) for Application Gateway.
     - `AzureBastionSubnet` (e.g., `10.0.4.0/24`) - *Name must be exactly this*.
4. Click **Review + create**, then **Create**.

## 3. Storage Account
*Used for diagnostic logs, persistent volumes, or storing Terraform state.*
1. Search for **Storage accounts** and click **+ Create**.
2. **Basics:** Select `shopverse-rg`, provide a globally unique name (e.g., `shopversestoragedev`), Region: same as RG, Performance: Standard, Redundancy: LRS.
3. Click **Review + create**, then **Create**.

## 4. Observability Stack
### 4.1 Log Analytics Workspace
1. Search for **Log Analytics workspaces** and click **+ Create**.
2. Select `shopverse-rg`, name it `shopverse-logs`, and select your region.
3. Click **Review + create**, then **Create**.

### 4.2 Application Insights
1. Search for **Application Insights** and click **+ Create**.
2. Select `shopverse-rg`, name it `shopverse-appinsights`.
3. Ensure **Workspace-based** is selected and choose `shopverse-logs`.
4. Click **Review + create**, then **Create**.

### 4.3 Azure Monitor workspace (Managed Prometheus)
1. Search for **Azure Monitor workspaces** and click **+ Create**.
2. Select `shopverse-rg`, name it `shopverse-prometheus`, and select your region.
3. Click **Review + create**, then **Create**.

### 4.4 Azure Managed Grafana
1. Search for **Azure Managed Grafana** and click **+ Create**.
2. Select `shopverse-rg`, name it `shopverse-grafana`, and select your region.
3. In the **Azure Monitor workspace** integration section, link it to `shopverse-prometheus`.
4. Click **Review + create**, then **Create**.

## 5. Azure Container Registry (ACR)
1. Search for **Container registries** and click **+ Create**.
2. **Basics:** Select `shopverse-rg`, provide a globally unique name (e.g., `shopverseregistry`), select your region, and choose the `Standard` SKU.
3. Click **Review + create**, then **Create**.

## 6. Azure Key Vault & Secrets
1. Search for **Key vaults** and click **+ Create**.
2. **Basics:** Select `shopverse-rg`, provide a globally unique name (e.g., `shopverse-kv`), select your region, and choose the `Standard` pricing tier.
3. **Access Configuration:** Select **Azure role-based access control (RBAC)**.
4. Click **Review + create**, then **Create**.
5. **Assign Permissions:** Once created, go to **Access control (IAM)** -> **Add role assignment** -> Grant your user account the **Key Vault Secrets Officer** role.
6. **Create Secrets:** Go to **Secrets** -> **Generate/Import**.
   - Create a secret named `DB-PASSWORD` and provide a strong password.
   - Create a secret named `JWT-SECRET` and provide a secure signing key.

## 7. Azure Database for MySQL - Flexible Server
1. Search for **Azure Database for MySQL servers** and select it.
2. Click **+ Create** and choose **Flexible server**.
3. **Basics:** 
   - Resource group: `shopverse-rg`.
   - Server name: `shopverse-mysql` (must be globally unique).
   - MySQL version: `8.0`.
   - Setup Admin username and use the password you stored in Key Vault.
4. **Compute + Storage:**
   - Compute tier: Choose based on needs (e.g., General Purpose).
   - **High Availability:** Check the box for **Zone-redundant HA**.
   - **Backup:** Configure backup retention (e.g., 7 days) and Geo-redundancy if needed.
5. **Networking:** 
   - Connectivity method: **Private access (VNet Integration)**.
   - Virtual network: Select `shopverse-vnet`.
   - Subnet: Select the delegated `db-subnet`.
6. Click **Review + create**, then **Create**.

## 8. Azure Kubernetes Service (AKS)
1. Search for **Kubernetes services** and click **+ Create** -> **Create a Kubernetes cluster**.
2. **Basics:** Select `shopverse-rg`, name it `shopverse-cluster`, choose your region.
3. **Node pools:** Adjust sizes as needed (e.g., `Standard_D2s_v3`).
4. **Networking:**
   - Network configuration: **Azure CNI**.
   - Virtual network: Select `shopverse-vnet`.
   - Cluster subnet: Select `aks-subnet`.
5. **Integrations:**
   - Container registry: Select your ACR (`shopverseregistry`).
   - Azure Monitor: Enable and select your Log Analytics workspace and Managed Prometheus workspace.
6. **Advanced (Add-ons):**
   - **Enable Application Gateway Ingress Controller:** Check this box and select the Application Gateway you create in Step 11 (or allow AKS to create a new one).
   - **Enable Secret Store CSI Driver:** Check this box to allow AKS to read from Key Vault.
7. Click **Review + create**, then **Create**.

## 9. Identity & Permissions (RBAC)
After creating AKS, Key Vault, and ACR, you must ensure AKS has the correct permissions:
1. **ACR Pull:** Ensure the AKS agent pool managed identity has the `AcrPull` role assigned on the ACR resource.
2. **Key Vault Read:** Ensure the AKS Key Vault Secret Provider managed identity has the `Key Vault Secrets User` role assigned on the Key Vault resource.

## 10. Azure GitOps (Argo CD) for AKS
*Required to deploy the applications via GitOps.*
1. Navigate to your created `shopverse-cluster` in the Azure Portal.
2. Under the **Settings** menu on the left, select **GitOps**.
3. Click **+ Create**.
4. Set the **Extension instance name** to `shopverse-argocd`.
5. Ensure the extension type is **Argo CD**.
6. Follow the prompts to point it to your GitHub repository and the deployment branch (e.g., `develop`).
7. Click **Create**.

## 11. Azure Application Gateway
*(If not created automatically via the AKS AGIC Add-on in Step 8)*
1. Search for **Application gateways** and click **+ Create**.
2. **Basics:** Select `shopverse-rg`, name it `shopverse-appgw`, Tier: `WAF V2`.
3. **Virtual network:** Select `shopverse-vnet` and `appgw-subnet`.
4. **Frontends:** Add a new public IP address (e.g., `shopverse-appgw-pip`).
5. **Backends:** Create an empty backend pool (AGIC will manage this later).
6. **Configuration:** Add a basic routing rule (HTTP, port 80) pointing the frontend IP to the empty backend pool.
7. Click **Review + create**, then **Create**.

## 12. Azure Front Door & WAF Policy
### 12.1 Front Door Profile
1. Search for **Front Door and CDN profiles** and click **+ Create**.
2. Select **Explore other offerings** -> **Azure Front Door (classic)** (or Standard/Premium based on needs) -> **Continue**.
3. **Basics:** Select `shopverse-rg`, select a location.
4. **Configuration:** 
   - **Frontend/domains:** Add a custom domain (e.g., `shopverse.yourdomain.com`). Select **Enable Custom Domain HTTPS** and choose **Front Door managed** to automatically provision the TLS certificate.
   - **Backend pools:** Add your Application Gateway's Public IP as the backend.
   - **Routing rules:** Route `/*` traffic to the backend pool.
5. Click **Review + create**, then **Create**.

### 12.2 Front Door WAF Policy
1. Search for **Web Application Firewall policies (WAF)** and click **+ Create**.
2. **Basics:** Select Policy for `Global WAF (Front Door)`, name it `shopversefdwaf`, Region: Global.
3. **Association:** Associate this policy with the Front Door profile you just created.
4. Click **Review + create**, then **Create**.

## 13. Azure DNS Zone
1. Search for **DNS zones** and click **+ Create**.
2. **Basics:** Select `shopverse-rg`, enter your domain name (e.g., `shopverse.yourdomain.com`).
3. Click **Review + create**, then **Create**.
*Note: Point your custom domain's CNAME record to the Azure Front Door endpoint, or update your registrar's NS records if hosting the apex domain.*

## 14. Entra ID (Azure AD) App Registration for GitHub Actions (OIDC)
*Required to run the CI/CD pipelines without storing client secrets.*
1. Search for **Microsoft Entra ID** -> **App registrations** -> **New registration**.
2. Name it `shopverse-github-actions` and click **Register**. Take note of the **Application (client) ID** and **Directory (tenant) ID**.
3. Go to **Certificates & secrets** -> **Federated credentials** -> **Add credential**.
4. Select **GitHub Actions deploying Azure resources**.
5. Enter the Organization, Repository, and Entity type (e.g., `Branch` named `develop` or `main`).
6. Click **Add**.
7. Go back to your Resource Group (`shopverse-rg`), click **Access control (IAM)**, and assign the **Contributor** role to this new App Registration.

## 15. Azure Bastion (Optional - For Secure Internal Access)
1. Search for **Bastions** and click **+ Create**.
2. **Basics:** Select `shopverse-rg`, name it `shopverse-bastion`, select your region.
3. **Virtual network:** Select `shopverse-vnet`. (Ensure you created the `AzureBastionSubnet` in Step 2).
4. **Public IP address:** Create a new public IP for the Bastion host.
5. Click **Review + create**, then **Create**.
