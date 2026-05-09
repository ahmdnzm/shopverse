variable "aws_region" {
  description = "AWS region for ShopVerse infrastructure"
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Project name used as a prefix for shared resources"
  type        = string
  default     = "shopverse"
}

variable "environment" {
  description = "Environment label for shared resources"
  type        = string
  default     = "shared"
}

variable "vpc_cidr" {
  description = "VPC CIDR for the network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "cluster_name" {
  description = "Name of the shared EKS cluster"
  type        = string
  default     = "shopverse-cluster"
}

variable "node_count" {
  description = "Number of nodes in the EKS cluster"
  type        = number
  default     = 2
}

variable "dns_domain" {
  description = "Public Route 53 hosted zone domain"
  type        = string
  default     = "ahmdnzm.com"
}

variable "app_domain" {
  description = "Production application hostname"
  type        = string
  default     = "shopverse.ahmdnzm.com"
}

variable "dev_domain" {
  description = "Development application hostname"
  type        = string
  default     = "dev.shopverse.ahmdnzm.com"
}

variable "staging_domain" {
  description = "Staging application hostname"
  type        = string
  default     = "staging.shopverse.ahmdnzm.com"
}

variable "github_repository" {
  description = "GitHub repository in owner/name form allowed to deploy through IAM OIDC Federation"
  type        = string
}

variable "github_ref_pattern" {
  description = "GitHub ref pattern allowed to impersonate the deploy IAM role"
  type        = string
  default     = "refs/heads/*"
}
