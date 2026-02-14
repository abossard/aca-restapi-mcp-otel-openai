# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name != "" ? var.resource_group_name : local.resource_group_name
  location = var.location
  # azd-env-name tag enables azd to discover this RG during deploy
  tags = merge(var.tags, { "azd-env-name" = var.environment_name })
}
