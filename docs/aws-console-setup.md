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
4.  **Template:** Dev/Test (or Free Tier if eligible).
5.  **DB instance identifier:** `shopverse-mysql`.
6.  **Master username:** `admin`.
7.  **Master password:** Generate a strong password and save it.
8.  **Instance configuration:** `db.t3.micro`.
9.  **Connectivity:**
    - **VPC:** `shopverse-vpc`.
    - **DB Subnet Group:** `shopverse-db-subnet-group`.
    - **Public access:** No.
    - **VPC security group:** Choose existing, select `shopverse-rds-sg`.
10. **Additional configuration:**
    - **Initial database name:** `shopverse_dev`.
11. Click **Create database**.

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

## Step 10: Amazon CloudFront

*Note: This step should usually be performed after the application is deployed and the Load Balancer DNS is available.*

1.  Navigate to **CloudFront** > **Distributions** > **Create distribution**.
2.  **Origin domain:** Select the DNS name of the Application Load Balancer created by the EKS ingress controller.
3.  **Protocol:** HTTPS only.
4.  **Viewer protocol policy:** Redirect HTTP to HTTPS.
5.  **Allowed HTTP methods:** GET, HEAD, OPTIONS, PUT, POST, PATCH, DELETE.
6.  Click **Create distribution**.

---

## Step 11: IAM Role for Service Accounts (IRSA) - Backend Secrets

To allow the backend pods in EKS to read secrets from Secrets Manager, we need to create an IAM role with a trust relationship to the EKS OIDC provider.

1.  **Get EKS OIDC Provider URL:**
    - Navigate to **EKS** > **Clusters** > `shopverse-cluster`.
    - In the **Overview** tab, find and copy the **OpenID Connect provider URL**.
2.  **Create IAM Role:**
    - Navigate to **IAM** > **Roles** > **Create role**.
    - **Trusted entity type:** Web identity.
    - **Identity provider:** Select the URL that matches your EKS OIDC provider (you may need to create it in IAM > Identity Providers first if it's not there).
    - **Audience:** `sts.amazonaws.com`.
    - Click **Next**.
3.  **Attach Policy:**
    - Create a new policy or attach an inline one that allows `secretsmanager:GetSecretValue` and `secretsmanager:DescribeSecret` for the secrets created in Step 8.
    - Click **Next**.
4.  **Role name:** `shopverse-backend-secrets-role`.
5.  Click **Create role**.
6.  **Edit Trust Relationship:**
    - Go to the created role > **Trust relationships** > **Edit trust policy**.
    - Update the `StringEquals` condition to target the specific service account:
      `"oidc.eks.<region>.amazonaws.com/id/<ID>:sub": "system:serviceaccount:shopverse-dev:shopverse-backend"`
    - Click **Update policy**.
