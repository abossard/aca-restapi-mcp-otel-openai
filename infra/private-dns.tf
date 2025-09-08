# Private DNS Zones (conditional)
resource "azurerm_private_dns_zone" "ai_foundry" {
  count               = var.enable_private_endpoints && var.enable_ai_foundry ? 1 : 0
  name                = "privatelink.api.azureml.ms"
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone" "ai_services" {
  count               = var.enable_private_endpoints && var.enable_ai_foundry ? 1 : 0
  name                = "privatelink.openai.azure.com"
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone" "search" {
  count               = var.enable_private_endpoints ? 1 : 0
  name                = "privatelink.search.windows.net"
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone" "acr" {
  count               = var.enable_private_endpoints ? 1 : 0
  name                = "privatelink.azurecr.io"
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags
}

# DNS Links
resource "azurerm_private_dns_zone_virtual_network_link" "ai_foundry" {
  count                 = var.enable_private_endpoints && var.enable_ai_foundry ? 1 : 0
  name                  = "${var.project_name}-aifoundry-dns-link-${var.environment}"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.ai_foundry[0].name
  virtual_network_id    = azurerm_virtual_network.main[0].id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "ai_services" {
  count                 = var.enable_private_endpoints && var.enable_ai_foundry ? 1 : 0
  name                  = "${var.project_name}-aiservices-dns-link-${var.environment}"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.ai_services[0].name
  virtual_network_id    = azurerm_virtual_network.main[0].id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "search" {
  count                 = var.enable_private_endpoints ? 1 : 0
  name                  = "${var.project_name}-search-dns-link-${var.environment}"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.search[0].name
  virtual_network_id    = azurerm_virtual_network.main[0].id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "acr" {
  count                 = var.enable_private_endpoints ? 1 : 0
  name                  = "${var.project_name}-acr-dns-link-${var.environment}"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.acr[0].name
  virtual_network_id    = azurerm_virtual_network.main[0].id
  registration_enabled  = false
  tags                  = var.tags
}
