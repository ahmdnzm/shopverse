output "rds_hostname" {
  description = "RDS instance hostname"
  value       = aws_db_instance.this.address
}

output "rds_port" {
  description = "RDS port"
  value       = aws_db_instance.this.port
}

output "rds_db_name" {
  description = "RDS database name"
  value       = aws_db_instance.this.db_name
}

output "rds_username" {
  description = "RDS master username"
  value       = aws_db_instance.this.username
}

output "db_password_secret_arn" {
  description = "Secrets Manager ARN for the database password"
  value       = aws_secretsmanager_secret.db_password.arn
}

output "db_password_secret_name" {
  description = "Secrets Manager name for the database password"
  value       = aws_secretsmanager_secret.db_password.name
}

output "jwt_secret_arn" {
  description = "Secrets Manager ARN for the JWT secret"
  value       = aws_secretsmanager_secret.jwt_secret.arn
}

output "jwt_secret_name" {
  description = "Secrets Manager name for the JWT secret"
  value       = aws_secretsmanager_secret.jwt_secret.name
}

output "backend_secrets_role_arn" {
  description = "IAM Role ARN for backend secrets access (IRSA)"
  value       = aws_iam_role.backend_secrets.arn
}

output "cloudfront_domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = try(aws_cloudfront_distribution.this[0].domain_name, "")
}
