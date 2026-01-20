# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name != "" ? var.resource_group_name : "rg-${var.project_name}-${var.environment_name}"
  location = var.location
  # azd-env-name tag enables azd to discover this RG during deploy
  tags = merge(var.tags, { "azd-env-name" = var.environment_name })
}
