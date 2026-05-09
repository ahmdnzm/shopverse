output "mysql_server_name" {
  description = "MySQL Flexible Server name"
  value       = azurerm_mysql_flexible_server.this.name
}

output "mysql_host" {
  description = "MySQL Flexible Server FQDN"
  value       = azurerm_mysql_flexible_server.this.fqdn
}

output "mysql_port" {
  description = "MySQL port"
  value       = "3306"
}

output "mysql_database_name" {
  description = "Application database name"
  value       = azurerm_mysql_flexible_database.app.name
}

output "mysql_username" {
  description = "Application database username"
  value       = azurerm_mysql_flexible_server.this.administrator_login
}

output "key_vault_name" {
  description = "Key Vault name"
  value       = azurerm_key_vault.this.name
}

output "db_password_secret_name" {
  description = "Key Vault secret name containing the database password"
  value       = azurerm_key_vault_secret.db_password.name
}

output "jwt_secret_name" {
  description = "Key Vault secret name containing the JWT secret"
  value       = azurerm_key_vault_secret.jwt_secret.name
}
