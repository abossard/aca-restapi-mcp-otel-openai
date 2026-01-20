# Resource Group
locals {
  effective_env_name = var.azure_env_name != "" ? var.azure_env_name : var.environment
  rg_suffix = var.azure_env_name != "" && var.azure_env_name != var.environment ? format("%s-%s", var.environment, var.azure_env_name) : var.environment
}

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name != "" ? var.resource_group_name : format("rg-%s-%s", var.project_name, local.rg_suffix)
  location = var.location
  # Add azd-env-name so azd can associate this RG with the current environment (prefers AZURE_ENV_NAME when provided)
  tags = merge(var.tags, { "azd-env-name" = local.effective_env_name })
}
