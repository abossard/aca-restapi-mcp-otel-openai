# Azure AI Foundry Terraform Configuration

This document provides guidance for creating Azure AI Foundry workspaces using Terraform.

## Current Status (2024)

Azure AI Foundry can be created using Terraform through two approaches:

1. **Native AzureRM Provider**: Uses `azurerm_ai_foundry` resource (recommended)
2. **AzAPI Provider**: Uses raw Azure API for newer features

## Prerequisites

- Terraform >= 1.0
- AzureRM provider >= 4.0
- Azure subscription with appropriate permissions

## Approach 1: Native AzureRM Provider

### Required Providers

```hcl
terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      recover_soft_deleted_key_vaults    = false
      purge_soft_delete_on_destroy       = false
      purge_soft_deleted_keys_on_destroy = false
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}
```

### Basic AI Foundry Hub Configuration

```hcl
# Generate unique naming
resource "random_string" "unique" {
  length  = 8
  lower   = true
  numeric = false
  special = false
  upper   = false
}

# AI Foundry Hub (Workspace)
resource "azurerm_ai_foundry" "main" {
  name                = "${var.project_name}-aifoundry-${var.environment}-${random_string.unique.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  
  # Required dependencies
  application_insights_id = azurerm_application_insights.main.id
  key_vault_id           = azurerm_key_vault.main.id
  storage_account_id     = azurerm_storage_account.main.id
  container_registry_id  = azurerm_container_registry.main.id
  
  identity {
    type = "SystemAssigned"
  }
  
  tags = var.tags
}

# AI Foundry Project
resource "azurerm_ai_foundry_project" "main" {
  name         = "${var.project_name}-project-${var.environment}"
  location     = azurerm_resource_group.main.location
  hub_id       = azurerm_ai_foundry.main.id
  
  tags = var.tags
}
```

### Required Supporting Resources

```hcl
# Key Vault for AI Foundry
resource "azurerm_key_vault" "main" {
  name                = "${var.project_name}kv${random_string.unique.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"
  
  purge_protection_enabled = true
  
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id
    
    key_permissions = [
      "Create", "Get", "List", "Delete", "Update", "Purge"
    ]
    
    secret_permissions = [
      "Set", "Get", "Delete", "List", "Purge"
    ]
  }
  
  tags = var.tags
}

# Storage Account for AI Foundry
resource "azurerm_storage_account" "main" {
  name                     = "${replace(var.project_name, "-", "")}st${random_string.unique.result}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  
  tags = var.tags
}
```

## Approach 2: AzAPI Provider (Advanced Features)

For newer AI Foundry features, use the AzAPI provider:

```hcl
terraform {
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = ">= 2.2.0"
    }
  }
}

provider "azapi" {}

resource "azapi_resource" "ai_foundry" {
  type                      = "Microsoft.CognitiveServices/accounts@2024-06-01"
  name                      = "${var.project_name}-aifoundry-${var.environment}"
  parent_id                 = azurerm_resource_group.main.id
  location                  = var.location
  schema_validation_enabled = false
  
  body = {
    kind = "AIServices"
    sku = {
      name = "S0"
    }
    identity = {
      type = "SystemAssigned"
    }
    properties = {
      disableLocalAuth        = false
      allowProjectManagement = true
      customSubDomainName     = "${var.project_name}-aifoundry-${var.environment}"
    }
  }
  
  tags = var.tags
}
```

## Integration with Existing Resources

AI Foundry can integrate with your existing Azure OpenAI and AI Search services:

```hcl
# Connect existing OpenAI to AI Foundry
resource "azurerm_ai_foundry_connection_openai" "main" {
  name                = "openai-connection"
  ai_foundry_id      = azurerm_ai_foundry.main.id
  cognitive_account_id = azurerm_cognitive_account.openai.id
}

# Connect existing AI Search to AI Foundry
resource "azurerm_ai_foundry_connection_search" "main" {
  name             = "search-connection"
  ai_foundry_id   = azurerm_ai_foundry.main.id
  search_service_id = azurerm_search_service.main.id
}
```

## Variables and Outputs

### Variables

```hcl
variable "enable_ai_foundry" {
  description = "Enable Azure AI Foundry workspace"
  type        = bool
  default     = false
}

variable "ai_foundry_sku" {
  description = "AI Foundry SKU"
  type        = string
  default     = "S0"
}
```

### Outputs

```hcl
output "ai_foundry_id" {
  value = var.enable_ai_foundry ? azurerm_ai_foundry.main[0].id : null
}

output "ai_foundry_workspace_url" {
  value = var.enable_ai_foundry ? azurerm_ai_foundry.main[0].workspace_url : null
}

output "ai_foundry_project_id" {
  value = var.enable_ai_foundry ? azurerm_ai_foundry_project.main[0].id : null
}
```

## Security Considerations

### Private Endpoints

AI Foundry supports private endpoints for secure connectivity:

```hcl
resource "azurerm_private_endpoint" "ai_foundry" {
  count               = var.enable_private_endpoints && var.enable_ai_foundry ? 1 : 0
  name                = "${var.project_name}-aifoundry-pe-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.private_endpoints[0].id

  private_service_connection {
    name                           = "${var.project_name}-aifoundry-psc-${var.environment}"
    private_connection_resource_id = azurerm_ai_foundry.main[0].id
    subresource_names              = ["amlworkspace"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.ai_foundry[0].id]
  }

  tags = var.tags
}

resource "azurerm_private_dns_zone" "ai_foundry" {
  count               = var.enable_private_endpoints && var.enable_ai_foundry ? 1 : 0
  name                = "privatelink.api.azureml.ms"
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags
}
```

### RBAC Permissions

```hcl
resource "azurerm_role_assignment" "ai_foundry_contributor" {
  count                = var.enable_ai_foundry ? 1 : 0
  scope                = azurerm_ai_foundry.main[0].id
  role_definition_name = "AzureML Data Scientist"
  principal_id         = azurerm_user_assigned_identity.main.principal_id
}
```

## Best Practices

1. **Dependencies**: Always create supporting resources (Key Vault, Storage, Container Registry) before AI Foundry
2. **Naming**: Use consistent naming conventions with unique suffixes
3. **Security**: Enable private endpoints for production environments
4. **Cost**: Use appropriate SKUs based on workload requirements
5. **Integration**: Leverage existing Azure AI services rather than creating duplicates

## Cost Considerations

- AI Foundry Hub has different pricing tiers (Basic, Standard, Premium)
- Consider compute instance costs for model training/inference
- Storage costs for datasets and model artifacts
- Private endpoint costs if enabled

## Limitations

- Some newer AI Foundry features may require the AzAPI provider
- Regional availability may be limited
- Certain enterprise features require specific Azure subscription types

## Post-Provision: AI Search Index Creation

Azure AI Search indexes cannot be reliably created via Terraform/AzAPI due to schema validation issues. Use the `postprovision` hook in `azure.yaml` to create indexes after infrastructure is provisioned:

### azure.yaml Configuration

```yaml
hooks:
  postprovision:
    posix:
      shell: sh
      run: ./scripts/create-search-index.sh
```

### scripts/create-search-index.sh

```bash
#!/bin/bash
# Create the 'documents' index in Azure AI Search using Azure AD auth
# (Required when local_authentication_enabled = false on the search service)

set -e

SEARCH_SERVICE="${1:-aca-restapi-v2-search-mcpai}"
RG="${2:-rg-aca-restapi-v2-mcpai}"
INDEX_NAME="${3:-documents}"

echo "Getting Azure AD access token..."
ACCESS_TOKEN=$(az account get-access-token --resource "https://search.azure.com" --query "accessToken" -o tsv)

echo "Creating index '$INDEX_NAME' in $SEARCH_SERVICE..."
curl -s -X PUT \
    "https://${SEARCH_SERVICE}.search.windows.net/indexes/${INDEX_NAME}?api-version=2024-07-01" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -d '{
        "name": "'"${INDEX_NAME}"'",
        "fields": [
            {"name": "id", "type": "Edm.String", "key": true, "searchable": false},
            {"name": "content", "type": "Edm.String", "searchable": true, "analyzer": "standard.lucene"},
            {"name": "title", "type": "Edm.String", "searchable": true},
            {"name": "source", "type": "Edm.String", "filterable": true, "searchable": false}
        ]
    }'
```

This ensures the search index exists before the application attempts to use it.