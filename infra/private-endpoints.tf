# Private Endpoints (conditional)
resource "azurerm_private_endpoint" "ai_foundry" {
  count               = var.enable_private_endpoints && var.enable_ai_foundry ? 1 : 0
  name                = "${var.project_name}-aifoundry-pe-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.private_endpoints[0].id

  private_service_connection {
    name                           = "${var.project_name}-aifoundry-psc-${var.environment}"
    private_connection_resource_id = azurerm_ai_foundry.main[0].id
    subresource_names              = ["amlworkspace"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.ai_foundry[0].id]
  }

  tags = var.tags
}

resource "azurerm_private_endpoint" "ai_services" {
  count               = var.enable_private_endpoints && var.enable_ai_foundry ? 1 : 0
  name                = "${var.project_name}-aiservices-pe-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.private_endpoints[0].id

  private_service_connection {
    name                           = "${var.project_name}-aiservices-psc-${var.environment}"
    private_connection_resource_id = azurerm_cognitive_account.ai_services[0].id
    subresource_names              = ["account"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.ai_services[0].id]
  }

  tags = var.tags
}

resource "azurerm_private_endpoint" "search" {
  count               = var.enable_private_endpoints ? 1 : 0
  name                = "${var.project_name}-search-pe-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.private_endpoints[0].id

  private_service_connection {
    name                           = "${var.project_name}-search-psc-${var.environment}"
    private_connection_resource_id = azurerm_search_service.main.id
    subresource_names              = ["searchService"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.search[0].id]
  }

  tags = var.tags
}

resource "azurerm_private_endpoint" "acr" {
  count               = var.enable_private_endpoints ? 1 : 0
  name                = "${var.project_name}-acr-pe-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.private_endpoints[0].id

  private_service_connection {
    name                           = "${var.project_name}-acr-psc-${var.environment}"
    private_connection_resource_id = azurerm_container_registry.main.id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.acr[0].id]
  }

  tags = var.tags
}
