# Cognitive Services Account & Model Deployments (conditional)
resource "azurerm_cognitive_account" "ai_services" {
  count                         = var.enable_ai_foundry ? 1 : 0
  name                          = "${var.project_name}-aiservices-${var.environment_name}"
  location                      = azurerm_resource_group.main.location
  resource_group_name           = azurerm_resource_group.main.name
  kind                          = "OpenAI"
  sku_name                      = "S0"
  public_network_access_enabled = var.enable_private_endpoints ? false : true
  # Provide custom subdomain if supplied (required for private endpoint). Using null keeps provider default when blank.
  custom_subdomain_name = var.cognitive_services_custom_subdomain != "" ? var.cognitive_services_custom_subdomain : null
  # Entra ID only: disable local (key) authentication if supported by provider version.
  local_auth_enabled = false

  identity { type = "SystemAssigned" }

  tags = var.tags
}

resource "azurerm_cognitive_deployment" "gpt4o" {
  count                = var.enable_ai_foundry ? 1 : 0
  name                 = "gpt-4o"
  cognitive_account_id = azurerm_cognitive_account.ai_services[0].id

  model {
    format  = "OpenAI"
    name    = "gpt-4o"
    version = "2024-11-20"
  }

  sku {
    name     = "GlobalStandard"
    capacity = 1
  }
}

resource "azurerm_cognitive_deployment" "gpt4o_mini" {
  count                = var.enable_ai_foundry && var.ai_model_set == "full" ? 1 : 0
  name                 = "gpt-4o-mini"
  cognitive_account_id = azurerm_cognitive_account.ai_services[0].id

  model {
    format  = "OpenAI"
    name    = "gpt-4o-mini"
    version = "2024-07-18"
  }

  sku {
    name     = "GlobalStandard"
    capacity = 1
  }
}
