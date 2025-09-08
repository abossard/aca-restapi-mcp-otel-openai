# Identity & Supporting Data
resource "azurerm_user_assigned_identity" "main" {
  name                = "${var.project_name}-identity-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.tags
}

# Unique suffix for certain global names
resource "random_string" "unique" {
  length  = 8
  lower   = true
  numeric = false
  special = false
  upper   = false
}

data "azurerm_client_config" "current" {}
