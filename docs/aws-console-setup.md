# AWS Management Console Setup Guide for Shopverse

This guide provides step-by-step instructions to manually provision the AWS infrastructure for Shopverse using the AWS Management Console. This is an alternative to using the automated Terraform scripts.

## Prerequisites
- An AWS Account with Administrator access.
- A domain name (purchased via Route 53 or another provider).
- GitHub repository name (e.g., `your-username/shopverse-aws`).

---

## Step 1: Networking (VPC)

We will use the VPC Wizard to create a standard networking environment.

1.  Log in to the **AWS Management Console** and navigate to **VPC**.
2.  Click **Create VPC**.
3.  Select **"VPC and more"**.
4.  **Name tag auto-generation:** Enter `shopverse`.
5.  **IPv4 CIDR block:** `10.0.0.0/16`.
6.  **Number of Availability Zones (AZs):** 2.
7.  **Number of Public subnets:** 2.
8.  **Number of Private subnets:** 2.
9.  **NAT Gateways:** 1 per AZ (or 1 in a single AZ to save costs).
10. **DNS options:** Ensure both "Enable DNS support" and "Enable DNS hostnames" are checked.
11. Click **Create VPC**.

*Note: The wizard will automatically create the Internet Gateway, Route Tables, and Subnet associations.*

---

## Step 2: IAM Roles

### 2.1 EKS Cluster Role
1.  Navigate to **IAM** > **Roles** > **Create role**.
2.  Select **AWS service**, and under "Service or use case", select **EKS**.
3.  Select **EKS - Cluster** and click **Next**.
4.  The policy `AmazonEKSClusterPolicy` should be attached automatically. Click **Next**.
5.  **Role name:** `shopverse-cluster-role`.
6.  Click **Create role**.

### 2.2 EKS Node Group Role
1.  Navigate to **IAM** > **Roles** > **Create role**.
2.  Select **AWS service**, and under "Service or use case", select **EC2**. Click **Next**.
3.  Search for and attach the following policies:
    - `AmazonEKSWorkerNodePolicy`
    - `AmazonEKS_CNI_Policy`
    - `AmazonEC2ContainerRegistryReadOnly`
4.  Click **Next**.
5.  **Role name:** `shopverse-node-role`.
6.  Click **Create role**.

---

## Step 3: Amazon EKS Cluster

1.  Navigate to **Elastic Kubernetes Service (EKS)** > **Clusters** > **Create cluster**.
2.  **Name:** `shopverse-cluster`.
3.  **Cluster service role:** Select `shopverse-cluster-role`.
4.  Click **Next**.
5.  **VPC:** Select the `shopverse-vpc` created in Step 1.
6.  **Subnets:** Ensure the two public and two private subnets are selected.
7.  **Security groups:** The default security group is sufficient for now.
8.  Click **Next** through the logging and add-ons screens (default settings are fine).
9.  Review and click **Create**. (This takes 10-15 minutes).

---

## Step 4: EKS Managed Node Group

1.  Once the cluster status is **Active**, go to the cluster details, select the **Compute** tab.
2.  Click **Add node group**.
3.  **Name:** `shopverse-nodes`.
4.  **Node IAM Role:** Select `shopverse-node-role`.
5.  Click **Next**.
6.  **Instance types:** Select `t3.medium`.
7.  **Scaling config:** Set Desired: 2, Minimum: 2, Maximum: 4.
8.  Click **Next**.
9.  **Subnets:** Ensure only the **private** subnets are selected.
10. Click **Next**, review, and click **Create**.

---

## Step 5: Amazon ECR Repositories

1.  Navigate to **Elastic Container Registry (ECR)** > **Repositories**.
2.  Click **Create repository**.
3.  **Repository name:** `shopverse-frontend`.
4.  Click **Create repository**.
5.  Repeat the process for `shopverse-backend`.

---

## Step 6: Route 53 (DNS)

1.  Navigate to **Route 53** > **Hosted zones**.
2.  Click **Create hosted zone**.
3.  **Domain name:** Enter your purchased domain (e.g., `shopverse.com`).
4.  **Type:** Public hosted zone.
5.  Click **Create hosted zone**.

*Note: If your domain is registered elsewhere, copy the NS records provided by AWS to your domain registrar's configuration.*

---

## Step 7: Amazon RDS (MySQL)

### 7.1 Database Security Group
1.  Navigate to **VPC** > **Security Groups** > **Create security group**.
2.  **Name:** `shopverse-rds-sg`.
3.  **Description:** Allow MySQL from EKS nodes.
4.  **VPC:** Select `shopverse-vpc`.
5.  **Inbound rules:** Add rule. Type: MySQL/Aurora (3306). Source: Custom (Select the security group of the EKS cluster or the VPC CIDR `10.0.0.0/16`).
6.  Click **Create security group**.

### 7.2 Database Subnet Group
1.  Navigate to **RDS** > **Subnet groups** > **Create DB subnet group**.
2.  **Name:** `shopverse-db-subnet-group`.
3.  **VPC:** Select `shopverse-vpc`.
4.  **Availability Zones:** Select the 2 AZs used for the VPC.
5.  **Subnets:** Select the two **private** subnets.
6.  Click **Create**.

### 7.3 Create RDS Instance
1.  Navigate to **RDS** > **Databases** > **Create database**.
2.  **Method:** Standard create.
3.  **Engine type:** MySQL.
4.  **Template:** Production (or Dev/Test for lower cost).
5.  **Deployment options:** Select **Multi-AZ DB instance** for high availability.
6.  **DB instance identifier:** `shopverse-mysql`.
7.  **Master username:** `admin`.
8.  **Master password:** Generate a strong password and save it.
9.  **Instance configuration:** `db.t3.micro`.
10. **Connectivity:**
    - **VPC:** `shopverse-vpc`.
    - **DB Subnet Group:** `shopverse-db-subnet-group`.
    - **Public access:** No.
    - **VPC security group:** Choose existing, select `shopverse-rds-sg`.
11. **Additional configuration:**
    - **Initial database name:** `shopverse_dev`.
    - **Backup:** Ensure "Enable automatic backups" is checked.
12. Click **Create database**.

---

## Step 8: AWS Secrets Manager

1.  Navigate to **Secrets Manager** > **Store a new secret**.
2.  **Secret type:** Other type of secret.
3.  **Key/value pairs:**
    - Key: `password`, Value: (The RDS master password from Step 7).
4.  Click **Next**.
5.  **Secret name:** `shopverse/dev/db-password`.
6.  Click **Next** and **Store**.
7.  Repeat for `shopverse/dev/jwt-secret` with a random string as the value.

---

## Step 9: GitHub Actions OIDC Integration

1.  Navigate to **IAM** > **Identity providers** > **Add provider**.
2.  **Provider type:** OpenID Connect.
3.  **Provider URL:** `https://token.actions.githubusercontent.com`.
4.  **Audience:** `sts.amazonaws.com`.
5.  Click **Add provider**.
6.  Navigate to **IAM** > **Roles** > **Create role**.
7.  **Trusted entity type:** Web identity.
8.  Select the GitHub provider and the audience created above.
9.  Enter your GitHub Organization and Repository.
10. Attach the `AdministratorAccess` policy (or a more scoped policy for deployment).
11. **Role name:** `shopverse-github-actions-role`.
12. Click **Create role**.

---

## Step 10: EKS Cluster Add-ons

After the cluster and nodes are active, you must install the following controllers to support the architecture.

### 10.1 AWS Load Balancer Controller
1.  **Create IAM Policy:** Download the policy from AWS and create it in IAM:
    ```bash
    curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.5.4/docs/install/iam_policy.json
    aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy --policy-document file://iam_policy.json
    ```
2.  **Create IAM Role for Service Account (IRSA):** Use `eksctl` or follow the manual IAM steps from Step 11 to create a role named `aws-load-balancer-controller` in the `kube-system` namespace, attached to the policy created above.
3.  **Install via Helm:**
    ```bash
    helm repo add eks https://aws.github.io/eks-charts
    helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
      -n kube-system \
      --set clusterName=shopverse-cluster \
      --set serviceAccount.create=false \
      --set serviceAccount.name=aws-load-balancer-controller
    ```

### 10.2 Secrets Store CSI Driver (AWS Provider)
1.  **Install the CSI Driver:**
    ```bash
    helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
    helm install csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver \
      --namespace kube-system \
      --set syncSecret.enabled=true
    ```
2.  **Install the AWS Provider:**
    ```bash
    kubectl apply -f https://raw.githubusercontent.com/aws/secrets-store-csi-driver-provider-aws/main/deployment/aws-provider-installer.yaml
    ```

### 10.3 Argo CD
1.  **Install Argo CD:**
    ```bash
    kubectl create namespace argocd
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    ```
2.  **Access the Argo CD API Server:** By default, it's not exposed. You can use port-forwarding:
    ```bash
    kubectl port-forward svc/argocd-server -n argocd 8080:443
    ```

---

## Step 11: IAM Role for Service Accounts (IRSA) - Backend Secrets

To allow the backend pods in EKS to read secrets from Secrets Manager, you must register the cluster's OIDC provider in IAM and then create a role.

### 11.1 Register OIDC Provider
1.  **Get EKS OIDC Provider URL:**
    - Navigate to **EKS** > **Clusters** > `shopverse-cluster`.
    - In the **Overview** tab, find and copy the **OpenID Connect provider URL**.
2.  **Add Identity Provider in IAM:**
    - Navigate to **IAM** > **Identity providers** > **Add provider**.
    - **Provider type:** OpenID Connect.
    - **Provider URL:** Paste the URL from EKS.
    - **Audience:** `sts.amazonaws.com`.
    - Click **Get thumbprint** and then **Add provider**.

### 11.2 Create IAM Role for Backend
1.  Navigate to **IAM** > **Roles** > **Create role**.
2.  **Trusted entity type:** Web identity.
3.  **Identity provider:** Select the provider matching your EKS OIDC URL.
4.  **Audience:** `sts.amazonaws.com`.
5.  Click **Next**.
6.  **Attach Policy:**
    - Create a new policy that allows `secretsmanager:GetSecretValue` and `secretsmanager:DescribeSecret` for your secrets.
    - Click **Next**.
7.  **Role name:** `shopverse-backend-secrets-role`.
8.  Click **Create role**.
9.  **Edit Trust Relationship:**
    - Update the `StringEquals` condition to target the specific service account:
      `"oidc.eks.<region>.amazonaws.com/id/<ID>:sub": "system:serviceaccount:shopverse-dev:shopverse-backend"`
    - Click **Update policy**.

---

## Step 12: AWS Certificate Manager (ACM)

To enable HTTPS/TLS, you need certificates for your domain.

1.  **Certificate for CloudFront:**
    - Navigate to **Certificate Manager** > **Request**.
    - **Region:** You MUST switch to **us-east-1 (N. Virginia)** for CloudFront.
    - **Domain name:** `*.yourdomain.com` (or specific subdomains).
    - **Validation:** DNS validation.
    - Click **Request**.
    - In the certificate details, click **Create records in Route 53** to complete validation.
2.  **Certificate for ALB (Optional):**
    - Repeat the process in your cluster's **local region** (e.g., `ap-southeast-1`) if you want TLS between CloudFront and the Load Balancer.

---

## Step 13: AWS Observability Stack

### 13.1 Amazon Managed Prometheus
1.  Navigate to **Amazon Managed Service for Prometheus** > **Workspaces**.
2.  Click **Create workspace**.
3.  **Workspace name:** `shopverse-prometheus`.
4.  Click **Create workspace**.

### 13.2 CloudWatch Log Group
1.  Navigate to **CloudWatch** > **Logs** > **Log groups**.
2.  Click **Create log group**.
3.  **Log group name:** `/aws/eks/shopverse-cluster/logs`.
4.  **Retention setting:** Select 30 days (or as preferred).
5.  Click **Create**.

---

## Step 14: Amazon CloudFront

*Note: This step should be performed after the application is deployed and the Load Balancer DNS is available from the EKS ingress.*

1.  Navigate to **CloudFront** > **Distributions** > **Create distribution**.
2.  **Origin domain:** Select the DNS name of the Application Load Balancer.
3.  **Viewer protocol policy:** Redirect HTTP to HTTPS.
4.  **Allowed HTTP methods:** GET, HEAD, OPTIONS, PUT, POST, PATCH, DELETE.
5.  **Settings - Alternate domain name (CNAME):** Add your custom domain (e.g., `shop.yourdomain.com`).
6.  **Settings - Custom SSL certificate:** Select the ACM certificate created in **Step 12** (us-east-1).
7.  Click **Create distribution**.

---

## Step 15: AWS WAF (Web Application Firewall)

1.  Navigate to **WAF & Shield** > **Web ACLs**.
2.  Ensure the region is set to **Global (CloudFront)**.
3.  Click **Create web ACL**.
4.  **Name:** `shopverse-waf`.
5.  **Resource type:** CloudFront distributions.
6.  **Associated AWS resources:** Add the CloudFront distribution created in **Step 14**.
7.  **Default action:** Allow.
8.  Add rules as needed (e.g., AWS Managed Rules like `AWSManagedRulesCommonRuleSet`).
9.  Complete the wizard and click **Create web ACL**.

---

## Step 16: Kubernetes Application Configuration

Finally, configure the Kubernetes-specific objects required for the architecture.

### 16.1 Secrets Store CSI - SecretProviderClass
Apply a manifest to map Secrets Manager to a Kubernetes secret:
```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: shopverse-secrets
  namespace: shopverse-dev
spec:
  provider: aws
  parameters:
    objects: |
      - objectName: "shopverse/dev/db-password"
        objectType: "secretsmanager"
        jmesPath: 
          - path: "password"
            objectAlias: "DB_PASSWORD"
  secretObjects:
    - secretName: shopverse-secret
      type: Opaque
      data:
        - objectName: DB_PASSWORD
          key: DB_PASSWORD
```

### 16.2 Metrics Collection (ADOT)
1.  **Create IAM Role for ADOT (IRSA):**
    - Create an IAM role named `shopverse-adot-role` using the OIDC provider (same process as Step 11).
    - Attach the following managed policies:
        - `AmazonPrometheusRemoteWriteAccess`
        - `CloudWatchAgentServerPolicy`
        - `AWSXrayWriteOnlyAccess`
    - Update the trust policy to target the service account: `system:serviceaccount:other-namespaces:adot-collector` (or specific namespace).
2.  **Install ADOT Operator:**
    ```bash
    kubectl apply -f https://github.com/aws-observations/aws-otel-collector/releases/latest/download/adot-operator.yaml
    ```
3.  **Deploy Collector:** Apply an `OpenTelemetryCollector` manifest configured to scrape `/metrics` and remote-write to your Prometheus workspace, using the IAM role above.

### 16.3 Final Deployment via Argo CD
1.  Navigate to the Argo CD UI (via port-forward in Step 10.3).
2.  Click **New App**.
3.  **Application Name:** `shopverse-dev`.
4.  **Project:** `default`.
5.  **Source Repository:** Your GitHub URL.
6.  **Path:** `helm/shopverse`.
7.  **Destination Cluster:** `https://kubernetes.default.svc`.
8.  **Namespace:** `shopverse-dev`.
9.  **Helm Parameters:** Override `image.tag` with your pushed tag from Step 4.
10. Click **Create** and **Sync**.

---

## Step 17: Finalize DNS (Route 53)

To make your application accessible via your domain, point Route 53 to CloudFront.

1.  Navigate to **Route 53** > **Hosted zones** > Select your zone.
2.  Click **Create record**.
3.  **Record name:** e.g., `shop` (to match `shop.yourdomain.com`).
4.  **Record type:** A - Routes traffic to an IPv4 address and some AWS resources.
5.  **Alias:** Toggle to **On**.
6.  **Route traffic to:**
    - Alias to CloudFront distribution.
    - Select the distribution created in **Step 14**.
7.  Click **Create records**.
