# Core Networking (conditional)
resource "azurerm_virtual_network" "main" {
  count               = var.enable_private_endpoints ? 1 : 0
  name                = "${var.project_name}-vnet-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = var.vnet_address_space
  tags                = var.tags
}

resource "azurerm_subnet" "private_endpoints" {
  count                = var.enable_private_endpoints ? 1 : 0
  name                 = "${var.project_name}-pe-subnet-${var.environment}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main[0].name
  address_prefixes     = var.private_endpoint_subnet_address_prefixes
}
