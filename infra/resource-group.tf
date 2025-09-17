# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name != "" ? var.resource_group_name : format("rg-%s-%s", var.project_name, var.environment)
  location = var.location
  # Add azd-env-name so azd can associate this RG with the current environment
  tags = merge(var.tags, { "azd-env-name" = var.environment })
}
