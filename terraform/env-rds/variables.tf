variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "shopverse"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "tf_state_bucket" {
  description = "S3 bucket containing Terraform state"
  type        = string
}

variable "core_state_key" {
  description = "State key path for the shared core Terraform state"
  type        = string
  default     = "core"
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = null
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "shopverse"
}

variable "db_version" {
  description = "MySQL engine version"
  type        = string
  default     = "8.0"
}

variable "db_instance_class" {
  description = "RDS instance class override"
  type        = string
  default     = null
}

variable "db_allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = null
}

variable "db_multi_az" {
  description = "Enable Multi-AZ"
  type        = bool
  default     = null
}

variable "alb_dns_name" {
  description = "DNS name of the ALB created by the ingress controller"
  type        = string
  default     = ""
}
