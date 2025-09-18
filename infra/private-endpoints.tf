############################################
# Private Endpoints via reusable module
############################################

module "private_link_ai_foundry" {
  source              = "./modules/private_link"
  enable              = var.enable_private_endpoints && var.enable_ai_foundry
  name_prefix         = "${var.project_name}-aifoundry"
  environment         = var.environment
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  subnet_id           = var.enable_private_endpoints ? azurerm_subnet.private_endpoints[0].id : null
  vnet_id             = var.enable_private_endpoints ? azurerm_virtual_network.main[0].id : null
  dns_zone_name       = "privatelink.api.azureml.ms"
  tags                = var.tags
  targets = var.enable_ai_foundry ? [{
    id                = azurerm_ai_foundry.main[0].id
    name              = "hub"
    subresource_names = ["amlworkspace"]
  }] : []
}

module "private_link_ai_services" {
  source = "./modules/private_link"
  # Require subdomain to be set before attempting private endpoint for Cognitive Services
  enable              = var.enable_private_endpoints && var.enable_ai_foundry && var.cognitive_services_custom_subdomain != ""
  name_prefix         = "${var.project_name}-aiservices"
  environment         = var.environment
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  subnet_id           = var.enable_private_endpoints ? azurerm_subnet.private_endpoints[0].id : null
  vnet_id             = var.enable_private_endpoints ? azurerm_virtual_network.main[0].id : null
  dns_zone_name       = "privatelink.openai.azure.com"
  tags                = var.tags
  targets = var.enable_ai_foundry ? [{
    id                = azurerm_cognitive_account.ai_services[0].id
    name              = "openai"
    subresource_names = ["account"]
  }] : []
}

module "private_link_search" {
  source              = "./modules/private_link"
  enable              = var.enable_private_endpoints
  name_prefix         = "${var.project_name}-search"
  environment         = var.environment
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  subnet_id           = var.enable_private_endpoints ? azurerm_subnet.private_endpoints[0].id : null
  vnet_id             = var.enable_private_endpoints ? azurerm_virtual_network.main[0].id : null
  dns_zone_name       = "privatelink.search.windows.net"
  tags                = var.tags
  targets = [{
    id                = azurerm_search_service.main.id
    name              = "search"
    subresource_names = ["searchService"]
  }]
}

module "private_link_acr" {
  source = "./modules/private_link"
  # ACR private endpoints require Premium SKU
  enable              = var.enable_private_endpoints && var.container_registry_sku == "Premium"
  name_prefix         = "${var.project_name}-acr"
  environment         = var.environment
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  subnet_id           = var.enable_private_endpoints ? azurerm_subnet.private_endpoints[0].id : null
  vnet_id             = var.enable_private_endpoints ? azurerm_virtual_network.main[0].id : null
  dns_zone_name       = "privatelink.azurecr.io"
  tags                = var.tags
  targets = [{
    id                = azurerm_container_registry.main.id
    name              = "acr"
    subresource_names = ["registry"]
  }]
}
