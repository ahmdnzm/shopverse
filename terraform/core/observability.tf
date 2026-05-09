resource "azurerm_log_analytics_workspace" "this" {
  name                = "${var.project_name}-law"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.labels
}

resource "azurerm_monitor_workspace" "prometheus" {
  name                = "${var.project_name}-prometheus"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = local.labels
}

resource "azurerm_monitor_action_group" "alerts" {
  name                = "${var.project_name}-alerts"
  resource_group_name = azurerm_resource_group.this.name
  short_name          = "alerts"

  dynamic "email_receiver" {
    for_each = var.monitor_action_group_ids
    content {
      name          = "notify"
      email_address = email_receiver.value
    }
  }
}

resource "azurerm_application_insights" "this" {
  name                = "${var.project_name}-ai"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  workspace_id        = azurerm_log_analytics_workspace.this.id
  application_type    = "web"
  tags                = local.labels
}

resource "azurerm_application_insights_standard_web_test" "prod_health" {
  name                    = "shopverse-prod-health"
  resource_group_name     = azurerm_resource_group.this.name
  location                = azurerm_resource_group.this.location
  application_insights_id = azurerm_application_insights.this.id
  description             = "ShopVerse prod /health uptime check"
  enabled                 = true
  frequency               = 300
  timeout                 = 30
  geo_locations           = ["us-va-ash-azr", "emea-nl-ams-azr", "apac-sg-sin-azr"]

  request {
    url = "https://${var.app_domain}/health"
  }

  validation_rules {
    expected_status_code = 200
  }
}

# Dashboard replacement (simplified)
resource "azurerm_portal_dashboard" "shopverse" {
  name                = "shopverse-observability"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = local.labels

  dashboard_properties = jsonencode({
    lenses = {
      "0" = {
        order = 0
        parts = {
          "0" = {
            position = {
              x      = 0
              y      = 0
              colSpan = 6
              rowSpan = 4
            }
            metadata = {
              inputs = []
              type   = "Extension/HubsExtension/PartType/MarkdownPart"
              settings = {
                content = "## ShopVerse Observability Dashboard\nMigrated from GCP Cloud Monitoring."
              }
            }
          }
        }
      }
    }
    metadata = {
      model = {
        timeRange = {
          value = {
            relative = {
              duration = 24
              timeUnit = 1
            }
          }
          type = "MsPortalFx.Composition.Configuration.TimeRange"
        }
      }
    }
  })
}
