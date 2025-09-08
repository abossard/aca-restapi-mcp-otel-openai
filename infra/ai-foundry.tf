# Azure AI Foundry Hub & Project (conditional)
resource "azurerm_ai_foundry" "main" {
  count               = var.enable_ai_foundry ? 1 : 0
  name                = "${var.project_name}-aifoundry-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  application_insights_id = azurerm_application_insights.main.id
  key_vault_id            = azurerm_key_vault.main[0].id
  storage_account_id      = azurerm_storage_account.main[0].id
  container_registry_id   = azurerm_container_registry.main.id

  identity { type = "SystemAssigned" }

  tags = var.tags
}

resource "azurerm_ai_foundry_project" "main" {
  count              = var.enable_ai_foundry ? 1 : 0
  name               = "${var.project_name}-project-${var.environment}"
  location           = azurerm_resource_group.main.location
  ai_services_hub_id = azurerm_ai_foundry.main[0].id
  tags               = var.tags

  # Add a system-assigned managed identity; API requires MSI-supporting client
  # (400 ValidationError previously: "Make sure to create your workspace using a client which support MSI")
  identity { type = "SystemAssigned" }
}
