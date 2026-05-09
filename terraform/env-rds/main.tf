locals {
  environment_defaults = {
    dev = {
      db_name             = "shopverse_dev"
      instance_class      = "db.t3.micro"
      allocated_storage   = 20
      multi_az            = false
      backup_retention    = 7
      deletion_protection = false
    }
    staging = {
      db_name             = "shopverse_staging"
      instance_class      = "db.t3.micro"
      allocated_storage   = 20
      multi_az            = false
      backup_retention    = 7
      deletion_protection = false
    }
    prod = {
      db_name             = "shopverse"
      instance_class      = "db.t3.small"
      allocated_storage   = 32
      multi_az            = true
      backup_retention    = 30
      deletion_protection = true
    }
  }

  defaults = local.environment_defaults[var.environment]
  name     = "${var.project_name}-${var.environment}"

  tags = {
    project     = var.project_name
    managed_by  = "terraform"
    environment = var.environment
  }
}

data "terraform_remote_state" "core" {
  backend = "s3"

  config = {
    bucket = var.tf_state_bucket
    key    = var.core_state_key
    region = var.aws_region
  }
}

resource "random_password" "db" {
  length           = 32
  special          = true
  override_special = "_%@"
}

# --- RDS Security Group ---
resource "aws_security_group" "db" {
  name        = "${local.name}-db-sg"
  description = "Allow MySQL traffic from EKS nodes"
  vpc_id      = data.terraform_remote_state.core.outputs.vpc_id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [data.terraform_remote_state.core.outputs.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

resource "aws_db_subnet_group" "this" {
  name       = "${local.name}-subnet-group"
  subnet_ids = data.terraform_remote_state.core.outputs.private_subnet_ids
  tags       = local.tags
}

resource "aws_db_instance" "this" {
  identifier           = "${local.name}-mysql"
  engine               = "mysql"
  engine_version       = var.db_version
  instance_class       = coalesce(var.db_instance_class, local.defaults.instance_class)
  allocated_storage    = coalesce(var.db_allocated_storage, local.defaults.allocated_storage)
  db_name              = coalesce(var.db_name, local.defaults.db_name)
  username             = var.db_username
  password             = random_password.db.result
  db_subnet_group_name = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db.id]
  multi_az             = coalesce(var.db_multi_az, local.defaults.multi_az)
  backup_retention_period = local.defaults.backup_retention
  deletion_protection  = local.defaults.deletion_protection
  skip_final_snapshot  = var.environment != "prod"
  
  tags = local.tags
}

# --- Secrets Manager ---
resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${local.name}-db-password"
  recovery_window_in_days = 0
  tags                    = local.tags
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db.result
}

resource "aws_secretsmanager_secret" "jwt_secret" {
  name                    = "${local.name}-jwt-secret"
  recovery_window_in_days = 0
  tags                    = local.tags
}

resource "aws_secretsmanager_secret_version" "jwt_secret" {
  secret_id     = aws_secretsmanager_secret.jwt_secret.id
  secret_string = "placeholder-to-be-overwritten-by-ci"

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# IAM Role for IRSA (Backend pod to read secrets)
resource "aws_iam_role" "backend_secrets" {
  name = "${local.name}-backend-secrets-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = data.terraform_remote_state.core.outputs.eks_oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${replace(data.terraform_remote_state.core.outputs.eks_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:shopverse-${var.environment}:shopverse-backend"
          }
        }
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_role_policy" "backend_secrets" {
  name = "secrets-read"
  role = aws_iam_role.backend_secrets.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Effect   = "Allow"
        Resource = [
          aws_secretsmanager_secret.db_password.arn,
          aws_secretsmanager_secret.jwt_secret.arn
        ]
      }
    ]
  })
}

# --- CloudFront ---
resource "aws_cloudfront_distribution" "this" {
  count = var.alb_dns_name != "" ? 1 : 0

  origin {
    domain_name = var.alb_dns_name
    origin_id   = "ALB"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CloudFront for ${local.name}"
  price_class         = "PriceClass_100"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "ALB"

    forwarded_values {
      query_string = true
      headers      = ["Host", "Authorization", "Origin"]

      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = local.tags
}
