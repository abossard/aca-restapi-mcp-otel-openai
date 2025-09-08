# Azure OpenAI Terraform Configuration

This document provides examples for creating Azure OpenAI resources using Terraform.

## Basic Configuration

Use `azurerm_cognitive_account` with `kind = "OpenAI"`:

```hcl
resource "azurerm_cognitive_account" "openai_service" {
  name                = "${var.project_name}-openai-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  kind                = "OpenAI"
  sku_name            = "S0"
  
  # Optional: Enable managed identity
  identity {
    type = "SystemAssigned"
  }
  
  tags = var.tags
}
```

## Model Deployment

Deploy GPT-4o models using `azurerm_cognitive_deployment`:

```hcl
resource "azurerm_cognitive_deployment" "gpt4o" {
  name                 = "gpt-4o"
  cognitive_account_id = azurerm_cognitive_account.openai_service.id
  
  model {
    format  = "OpenAI"
    name    = "gpt-4o"
    version = "2024-08-06"
  }
  
  scale {
    type     = "Standard"
    capacity = 10
  }
}

resource "azurerm_cognitive_deployment" "gpt4o_mini" {
  name                 = "gpt-4o-mini"
  cognitive_account_id = azurerm_cognitive_account.openai_service.id
  
  model {
    format  = "OpenAI"
    name    = "gpt-4o-mini"
    version = "2024-07-18"
  }
  
  scale {
    type     = "Standard"
    capacity = 10
  }
}
```

## Outputs

```hcl
output "openai_endpoint" {
  value = azurerm_cognitive_account.openai_service.endpoint
}

output "openai_primary_key" {
  value     = azurerm_cognitive_account.openai_service.primary_access_key
  sensitive = true
}
```

## Important Notes

- Regional quota limits: Only 3 OpenAI resources per region
- For advanced features (content filtering), consider using `azapi_resource`
- GPT-4o requires quota approval in some regions
- Use managed identity for secure authentication in production