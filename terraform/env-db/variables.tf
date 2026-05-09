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
  description = "Project name used as a prefix for database resources"
  type        = string
  default     = "shopverse"
}

variable "environment" {
  description = "Environment for this MySQL Flexible Server instance"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "tf_state_storage_account" {
  description = "Azure Storage Account containing Terraform state"
  type        = string
}

variable "tf_state_container" {
  description = "Azure Storage Container containing Terraform state"
  type        = string
}

variable "core_state_key" {
  description = "State key path for the shared core Terraform state"
  type        = string
  default     = "core"
}

variable "db_name" {
  description = "Optional database name override"
  type        = string
  default     = null
}

variable "db_username" {
  description = "Application database username"
  type        = string
  default     = "shopverse"
}

variable "db_version" {
  description = "Azure Database for MySQL Flexible Server version"
  type        = string
  default     = "8.0.21"
}

variable "db_tier" {
  description = "Optional MySQL compute tier override (e.g., Standard_B1ms)"
  type        = string
  default     = null
}

variable "db_disk_size_gb" {
  description = "Optional MySQL disk size override in GiB"
  type        = number
  default     = null
}

variable "db_high_availability" {
  description = "Optional MySQL high availability override (e.g., ZoneRedundant)"
  type        = bool
  default     = null
}

variable "db_backup_enabled" {
  description = "Optional automated backup override"
  type        = bool
  default     = null
}

variable "db_deletion_protection" {
  description = "Optional deletion protection override"
  type        = bool
  default     = null
}

variable "key_vault_name" {
  description = "Name of the Azure Key Vault"
  type        = string
}
