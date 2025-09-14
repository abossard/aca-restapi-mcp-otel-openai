terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.47.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 1.13" # Provides access to ARM resources not yet in azurerm (authConfigs)
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = var.allow_force_resource_group_delete ? false : true
    }
  }
  storage_use_azuread = true
}

# Generic ARM provider for unsupported / emerging resources
provider "azapi" {}
