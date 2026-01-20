# Azure OpenAI Terraform Configuration

This document describes the Azure OpenAI setup used in this project.

## Overview

This project uses Azure OpenAI via Cognitive Services with:
- Entra ID authentication only (no API keys)
- Custom subdomain (required for token auth)
- GPT-4o model deployments

## Implementation

### Cognitive Account

```hcl
resource "azurerm_cognitive_account" "ai_services" {
  count                         = var.enable_ai_foundry ? 1 : 0
  name                          = "${var.project_name}-aiservices-${var.environment_name}"
  location                      = azurerm_resource_group.main.location
  resource_group_name           = azurerm_resource_group.main.name
  kind                          = "OpenAI"
  sku_name                      = "S0"
  public_network_access_enabled = var.enable_private_endpoints ? false : true
  
  # REQUIRED for Entra ID auth
  custom_subdomain_name = "${var.project_name}-${var.environment_name}"
  local_auth_enabled    = false

  identity { type = "SystemAssigned" }
  tags = var.tags
}
```

### Model Deployments

```hcl
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
```

## Critical: Custom Subdomain

When `local_auth_enabled = false`, Azure **requires** a custom subdomain. Without it:

```
Please provide a custom subdomain for token authentication
```

This changes the endpoint from:
- `https://<region>.api.cognitive.microsoft.com/` (regional, requires API key)
- `https://<custom-subdomain>.openai.azure.com/` (custom, supports Entra ID)

## Python SDK Usage

```python
from azure.identity import DefaultAzureCredential

credential = DefaultAzureCredential()

# azure_ad_token_provider must be a CALLABLE that returns the token string
def get_token() -> str:
    return credential.get_token("https://cognitiveservices.azure.com/.default").token

client = AsyncAzureOpenAI(
    azure_endpoint=os.getenv("AZURE_OPENAI_ENDPOINT"),
    azure_ad_token_provider=get_token,  # Pass the function, not the result
    api_version="2024-02-01"
)
```

## Key Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `enable_ai_foundry` | bool | `true` | Enable OpenAI resources |
| `ai_model_set` | string | `"full"` | `minimal` or `full` |
| `cognitive_services_custom_subdomain` | string | `""` | Auto-generated if empty |

## RBAC Permissions

```hcl
resource "azurerm_role_assignment" "container_app_openai_user" {
  scope                = azurerm_cognitive_account.ai_services[0].id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = azurerm_user_assigned_identity.main.principal_id
}
```

## Common Issues

| Issue | Solution |
|-------|----------|
| Token auth error | Ensure `custom_subdomain_name` is set |
| `'AccessToken' object is not callable` | Pass a function to `azure_ad_token_provider`, not `get_token()` result |
| 403 Forbidden | Add `Cognitive Services OpenAI User` role |
| Provider race condition on endpoint | Re-run `azd up` |

## Outputs

```hcl
output "openai_endpoint" {
  value = azurerm_cognitive_account.ai_services[0].endpoint
}
```
