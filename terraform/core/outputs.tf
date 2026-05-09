output "vpc_id" {
  description = "AWS VPC ID"
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "AWS VPC CIDR"
  value       = aws_vpc.this.cidr_block
}

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.this.name
}

output "kubeconfig_command" {
  description = "Command to configure kubectl for the EKS cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.this.name}"
}

output "ecr_repository_urls" {
  description = "ECR repository URLs"
  value = {
    frontend = aws_ecr_repository.frontend.repository_url
    backend  = aws_ecr_repository.backend.repository_url
  }
}

output "route53_zone_id" {
  description = "Route 53 Hosted Zone ID"
  value       = aws_route53_zone.this.zone_id
}

output "route53_name_servers" {
  description = "Route 53 name servers for domain delegation"
  value       = aws_route53_zone.this.name_servers
}

output "github_actions_role_arn" {
  description = "IAM Role ARN for GitHub Actions"
  value       = aws_iam_role.github.arn
}

output "eks_oidc_provider_arn" {
  description = "EKS OIDC Provider ARN"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "eks_oidc_issuer_url" {
  description = "EKS OIDC Issuer URL"
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "viewer_domains" {
  description = "Public application domains by environment"
  value       = { for env, config in local.environments : env => config.domain }
}
