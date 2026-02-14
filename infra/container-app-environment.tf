# Container App Environment
resource "azurerm_container_app_environment" "main" {
  name                       = local.container_app_environment_name
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  logs_destination           = "log-analytics"
  infrastructure_subnet_id   = var.enable_private_endpoints ? azurerm_subnet.container_apps_infrastructure[0].id : null
  tags                       = var.tags
}
