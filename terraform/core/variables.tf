variable "resource_group_name" {
  description = "Azure Resource Group name for ShopVerse infrastructure"
  type        = string
}

variable "location" {
  description = "Default Azure location"
  type        = string
  default     = "southeastasia"
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

variable "network_cidr" {
  description = "Primary subnet CIDR for AKS nodes"
  type        = string
  default     = "10.10.0.0/20"
}

variable "pods_cidr" {
  description = "Secondary range CIDR for AKS Pods"
  type        = string
  default     = "10.20.0.0/16"
}

variable "services_cidr" {
  description = "Secondary range CIDR for AKS Services"
  type        = string
  default     = "10.30.0.0/20"
}

variable "cluster_name" {
  description = "Name of the shared AKS cluster"
  type        = string
  default     = "shopverse-cluster"
}

variable "node_count" {
  description = "Number of nodes in the AKS cluster"
  type        = number
  default     = 2
}

variable "dns_zone_name" {
  description = "Azure DNS managed zone name"
  type        = string
  default     = "shopverse-public"
}

variable "dns_domain" {
  description = "Public DNS zone suffix"
  type        = string
  default     = "ahmdnzm.com."
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
  description = "GitHub repository in owner/name form allowed to deploy through Workload Identity Federation"
  type        = string
}

variable "github_ref_pattern" {
  description = "GitHub ref pattern allowed to impersonate the deploy service account"
  type        = string
  default     = "refs/heads/.*"
}

variable "monitor_action_group_ids" {
  description = "Azure Monitor Action Group IDs to attach to ShopVerse alert policies"
  type        = list(string)
  default     = []
}
