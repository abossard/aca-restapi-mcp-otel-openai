# Azure AI Search Service
resource "azurerm_search_service" "main" {
  name                          = "${var.project_name}-search-${var.environment}"
  resource_group_name           = azurerm_resource_group.main.name
  location                      = azurerm_resource_group.main.location
  sku                           = "basic"
  replica_count                 = 1
  partition_count               = 1
  public_network_access_enabled = var.enable_private_endpoints ? false : true
  # Entra ID only (disable admin keys / local key auth)
  local_authentication_enabled  = false

  identity { type = "SystemAssigned" }

  tags = var.tags
}
