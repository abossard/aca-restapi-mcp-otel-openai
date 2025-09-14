# Container Registry
resource "azurerm_container_registry" "main" {
  name                          = "${replace(var.project_name, "-", "")}acr${var.environment}"
  resource_group_name           = azurerm_resource_group.main.name
  location                      = azurerm_resource_group.main.location
  sku                           = "Basic"
  admin_enabled                 = false # disable admin (username/password) access; use managed identity / AAD tokens
  public_network_access_enabled = var.enable_private_endpoints ? false : true
  tags                          = var.tags
}
