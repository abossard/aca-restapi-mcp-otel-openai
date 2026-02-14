# Monitoring: Log Analytics + Application Insights
resource "azurerm_log_analytics_workspace" "main" {
  name                = local.log_analytics_workspace_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_application_insights" "main" {
  name                          = local.app_insights_name
  location                      = azurerm_resource_group.main.location
  resource_group_name           = azurerm_resource_group.main.name
  workspace_id                  = azurerm_log_analytics_workspace.main.id
  application_type              = "web"
  local_authentication_disabled = var.application_insights_local_auth_enabled ? false : true
  tags                          = var.tags

  lifecycle {
    precondition {
      condition     = !(var.enable_container_apps_managed_otel && !var.application_insights_local_auth_enabled)
      error_message = "Container Apps managed OpenTelemetry requires Application Insights local authentication to be enabled."
    }
  }
}

# NOTE:
# The connection string is injected into the container app as the environment variable
#   APPLICATIONINSIGHTS_CONNECTION_STRING (standard name expected by Azure Monitor OTel Distro)
# Application code uses the distro when this variable is set; otherwise it falls back to manual OTLP export.
# To force manual OTLP export only, omit the variable from the container definition.
