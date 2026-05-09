output "resource_group_name" {
  description = "Azure Resource Group name"
  value       = azurerm_resource_group.this.name
}

output "location" {
  description = "Azure location"
  value       = azurerm_resource_group.this.location
}

output "network_name" {
  description = "Virtual Network name"
  value       = azurerm_virtual_network.this.name
}

output "cluster_name" {
  description = "AKS cluster name"
  value       = azurerm_kubernetes_cluster.this.name
}

output "kubeconfig_command" {
  description = "Command to configure kubectl for the AKS cluster"
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.this.name} --name ${azurerm_kubernetes_cluster.this.name}"
}

output "container_registry_name" {
  description = "Azure Container Registry name"
  value       = azurerm_container_registry.this.name
}

output "container_registry_login_server" {
  description = "Azure Container Registry login server"
  value       = azurerm_container_registry.this.login_server
}

output "ingress_ip_names" {
  description = "Public IP resource names by environment"
  value       = { for env, ip in azurerm_public_ip.ingress : env => ip.name }
}

output "ingress_ip_addresses" {
  description = "Public IP addresses by environment"
  value       = { for env, ip in azurerm_public_ip.ingress : env => ip.ip_address }
}

output "waf_policy_name" {
  description = "Azure WAF policy name"
  value       = azurerm_web_application_firewall_policy.this.name
}

output "viewer_domains" {
  description = "Public application domains by environment"
  value       = { for env, config in local.environments : env => config.domain }
}

output "dns_name_servers" {
  description = "Azure DNS name servers for domain delegation"
  value       = azurerm_dns_zone.this.name_servers
}

output "github_actions_client_id" {
  description = "Client ID for GitHub Actions application"
  value       = azuread_application.github.client_id
}

output "github_actions_principal_id" {
  description = "Principal ID for GitHub Actions service principal"
  value       = azuread_service_principal.github.object_id
}

output "aks_managed_identity_principal_id" {
  description = "Principal ID for AKS system-assigned managed identity"
  value       = azurerm_kubernetes_cluster.this.identity[0].principal_id
}

output "tenant_id" {
  description = "Azure Tenant ID"
  value       = data.azurerm_subscription.current.tenant_id
}

output "subscription_id" {
  description = "Azure Subscription ID"
  value       = data.azurerm_subscription.current.subscription_id
}
