locals {
  environment_defaults = {
    dev = {
      db_name             = "shopverse_dev"
      sku_name            = "B_Standard_B1ms"
      disk_size_gb        = 20
      ha_enabled          = false
      backup_retention    = 7
      deletion_protection = false
    }
    staging = {
      db_name             = "shopverse_staging"
      sku_name            = "B_Standard_B1ms"
      disk_size_gb        = 20
      ha_enabled          = false
      backup_retention    = 7
      deletion_protection = false
    }
    prod = {
      db_name             = "shopverse"
      sku_name            = "GP_Standard_D2ds_v4"
      disk_size_gb        = 32
      ha_enabled          = true
      backup_retention    = 30
      deletion_protection = true
    }
  }

  defaults = local.environment_defaults[var.environment]
  name     = "${var.project_name}-${var.environment}"

  labels = {
    project     = var.project_name
    managed_by  = "terraform"
    environment = var.environment
  }
}

data "terraform_remote_state" "core" {
  backend = "azurerm"

  config = {
    storage_account_name = var.tf_state_storage_account
    container_name       = var.tf_state_container
    key                  = var.core_state_key
  }
}

data "azurerm_client_config" "current" {}

resource "random_password" "db" {
  length           = 32
  special          = true
  override_special = "_%@"
}

resource "azurerm_subnet" "db" {
  name                 = "${local.name}-db-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = data.terraform_remote_state.core.outputs.network_name
  address_prefixes     = [var.environment == "prod" ? "10.20.0.0/24" : (var.environment == "staging" ? "10.21.0.0/24" : "10.22.0.0/24")]
  
  delegation {
    name = "fs"
    service_delegation {
      name    = "Microsoft.DBforMySQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_private_dns_zone" "db" {
  name                = "${local.name}.mysql.database.azure.com"
  resource_group_name = var.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "db" {
  name                  = "${local.name}-db-vnet-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.db.name
  virtual_network_id    = data.terraform_remote_state.core.outputs.vnet_id
}

resource "azurerm_mysql_flexible_server" "this" {
  name                = "${local.name}-mysql"
  resource_group_name = var.resource_group_name
  location            = var.location
  administrator_login = var.db_username
  administrator_password = random_password.db.result
  sku_name            = coalesce(var.db_tier, local.defaults.sku_name)
  version             = var.db_version

  delegated_subnet_id = azurerm_subnet.db.id
  private_dns_zone_id = azurerm_private_dns_zone.db.id

  storage {
    size_gb = coalesce(var.db_disk_size_gb, local.defaults.disk_size_gb)
  }

  backup_retention_days = local.defaults.backup_retention
  
  dynamic "high_availability" {
    for_each = coalesce(var.db_high_availability, local.defaults.ha_enabled) ? [1] : []
    content {
      mode = "ZoneRedundant"
    }
  }

  tags = local.labels

  depends_on = [azurerm_private_dns_zone_virtual_network_link.db]
}

resource "azurerm_mysql_flexible_database" "app" {
  name                = coalesce(var.db_name, local.defaults.db_name)
  resource_group_name = var.resource_group_name
  server_name         = azurerm_mysql_flexible_server.this.name
  charset             = "utf8"
  collation           = "utf8_general_ci"
}

resource "azurerm_key_vault" "this" {
  name                = var.key_vault_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  purge_protection_enabled = false
  enable_rbac_authorization = true
  
  tags = local.labels
}

resource "azurerm_key_vault_secret" "db_password" {
  name         = "db-password"
  value        = random_password.db.result
  key_vault_id = azurerm_key_vault.this.id
}

resource "azurerm_key_vault_secret" "jwt_secret" {
  name         = "jwt-secret"
  value        = "placeholder-to-be-overwritten-by-ci"
  key_vault_id = azurerm_key_vault.this.id

  lifecycle {
    ignore_changes = [value]
  }
}

# Grant AKS managed identity access to Key Vault secrets
resource "azurerm_role_assignment" "aks_kv_secrets_user" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = data.terraform_remote_state.core.outputs.aks_managed_identity_principal_id
}

# Grant GitHub Actions access to Key Vault for setting secrets
resource "azurerm_role_assignment" "github_kv_secrets_officer" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.terraform_remote_state.core.outputs.github_actions_principal_id
}
