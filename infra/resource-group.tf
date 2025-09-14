# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  # Add azd-env-name so azd can associate this RG with the current environment
  tags = merge(var.tags, { "azd-env-name" = var.environment })
}
