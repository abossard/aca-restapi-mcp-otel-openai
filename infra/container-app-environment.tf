# Container App Environment
resource "azurerm_container_app_environment" "main" {
  name                       = "${var.project_name}-cae-${var.environment}"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  logs_destination           = "log-analytics"
  tags                       = var.tags
}
