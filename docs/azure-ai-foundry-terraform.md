# Azure AI Foundry Terraform Configuration

This document describes the Azure AI Foundry setup used in this project.

## Overview

This project uses Azure AI Foundry with:
- **AI Foundry Hub**: Central workspace with shared resources
- **AI Foundry Project**: Project-level isolation
- **Azure OpenAI (Cognitive Services)**: GPT-4o model deployments

## Prerequisites

- Terraform >= 1.0
- AzureRM provider >= 4.0
- Azure subscription with AI Foundry access

## Implementation

### AI Foundry Hub

```hcl
resource "azurerm_ai_foundry" "main" {
  count               = var.enable_ai_foundry ? 1 : 0
  name                = "${var.project_name}-aifoundry-${var.environment_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  application_insights_id = azurerm_application_insights.main.id
  key_vault_id            = azurerm_key_vault.main[0].id
  storage_account_id      = azurerm_storage_account.main[0].id
  container_registry_id   = azurerm_container_registry.main.id

  identity { type = "SystemAssigned" }
  tags = var.tags
}
```

### AI Foundry Project

```hcl
resource "azurerm_ai_foundry_project" "main" {
  count              = var.enable_ai_foundry ? 1 : 0
  name               = "${var.project_name}-project-${var.environment_name}"
  location           = azurerm_resource_group.main.location
  ai_services_hub_id = azurerm_ai_foundry.main[0].id

  identity { type = "SystemAssigned" }
  tags = var.tags
}
```

### OpenAI (Cognitive Services)

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
```

## Key Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `enable_ai_foundry` | bool | `true` | Enable AI Foundry resources |
| `ai_model_set` | string | `"full"` | `minimal` or `full` (includes gpt-4o-mini) |
| `cognitive_services_custom_subdomain` | string | `""` | Auto-generated if empty |

## Critical: Custom Subdomain

When `local_auth_enabled = false` (Entra ID only), a custom subdomain is **required**. This project auto-generates it as `${project_name}-${environment_name}`.

## Deployment

```bash
azd up
```

## Common Issues

| Issue | Solution |
|-------|----------|
| Token auth error | Ensure custom subdomain is set |
| 403 on API calls | Add `Cognitive Services OpenAI User` role |
| Provider race condition | Re-run `azd up` |
