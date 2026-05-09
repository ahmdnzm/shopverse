locals {
  labels = {
    project     = var.project_name
    managed_by  = "terraform"
    environment = var.environment
  }

  environments = {
    dev = {
      domain = var.dev_domain
    }
    staging = {
      domain = var.staging_domain
    }
    prod = {
      domain = var.app_domain
    }
  }

  github_branches = ["main", "staging", "develop"]
}

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.labels
}

resource "azurerm_virtual_network" "this" {
  name                = "${var.project_name}-vnet"
  address_space       = ["10.0.0.0/8"]
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.labels
}

resource "azurerm_subnet" "aks" {
  name                 = "aks-subnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.network_cidr]
}

resource "azurerm_subnet" "appgw" {
  name                 = "appgw-subnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.10.16.0/24"]
}

resource "azurerm_public_ip" "ingress" {
  for_each = local.environments

  name                = "${var.project_name}-${each.key}-pip"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.labels
}

resource "azurerm_kubernetes_cluster" "this" {
  name                = var.cluster_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  dns_prefix          = var.project_name
  tags                = local.labels

  default_node_pool {
    name           = "default"
    node_count     = var.node_count
    vm_size        = "Standard_DS2_v2"
    vnet_subnet_id = azurerm_subnet.aks.id
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin     = "azure"
    service_cidr       = var.services_cidr
    dns_service_ip     = "10.30.0.10"
    docker_bridge_cidr = "172.17.0.1/16"
  }

  ingress_application_gateway {
    subnet_id = azurerm_subnet.appgw.id
  }

  azure_policy_enabled = true
}

resource "azurerm_container_registry" "this" {
  name                = replace("${var.project_name}registry", "-", "")
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku                 = "Standard"
  admin_enabled       = true
  tags                = local.labels
}

resource "azurerm_dns_zone" "this" {
  name                = var.dns_domain
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.labels
}

resource "azurerm_dns_a_record" "app" {
  for_each = local.environments

  name                = split(".", each.value.domain)[0]
  zone_name           = azurerm_dns_zone.this.name
  resource_group_name = azurerm_resource_group.this.name
  ttl                 = 300
  target_resource_id  = azurerm_public_ip.ingress[each.key].id
}

resource "azurerm_web_application_firewall_policy" "this" {
  name                = "${var.project_name}-waf"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = local.labels

  policy_settings {
    enabled                     = true
    mode                        = "Prevention"
    request_body_check          = true
    file_upload_limit_in_mb     = 100
    max_request_body_size_in_kb = 128
  }

  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.2"
    }
  }

  # Rate limiting is implemented via custom rules in App Gateway WAF v2
  custom_rules {
    name      = "RateLimitApi"
    priority  = 1
    rule_type = "RateLimitRule"
    action    = "Block"

    match_conditions {
      match_variables {
        variable_name = "RequestUri"
      }
      operator           = "BeginsWith"
      negation_condition = false
      match_values       = ["/api/"]
    }

    rate_limit_duration  = "OneMin"
    rate_limit_threshold = 300
  }
}

resource "azuread_application" "github" {
  display_name = "${var.project_name}-github-actions"
}

resource "azuread_service_principal" "github" {
  client_id = azuread_application.github.client_id
}

data "azurerm_subscription" "current" {}

resource "azurerm_role_assignment" "github_contributor" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.github.object_id
}

resource "azuread_application_federated_identity_credential" "github" {
  for_each = toset(local.github_branches)

  application_object_id = azuread_application.github.object_id
  display_name          = "github-actions-${each.key}"
  description           = "Allow GitHub Actions to deploy from ${each.key}"
  audiences             = ["api://AzureADTokenExchange"]
  issuer                = "https://token.actions.githubusercontent.com"
  subject               = "repo:${var.github_repository}:ref:refs/heads/${each.key}"
}
