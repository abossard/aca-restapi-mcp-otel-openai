# Azure AI Search Terraform Configuration

This document describes the Azure AI Search setup used in this project.

## Overview

This project uses Azure AI Search with:
- Entra ID authentication only (no API keys)
- Managed identity for secure access
- Basic SKU for development

## Implementation

### Search Service

```hcl
resource "azurerm_search_service" "main" {
  name                          = "${var.project_name}-search-${var.environment_name}"
  resource_group_name           = azurerm_resource_group.main.name
  location                      = azurerm_resource_group.main.location
  sku                           = "basic"
  replica_count                 = 1
  partition_count               = 1
  public_network_access_enabled = var.enable_private_endpoints ? false : true
  
  # Entra ID only - disable API keys
  local_authentication_enabled = false

  identity { type = "SystemAssigned" }
  tags = var.tags
}
```

## Key Settings

| Setting | Value | Purpose |
|---------|-------|---------|
| `sku` | `basic` | Suitable for development/small workloads |
| `local_authentication_enabled` | `false` | Forces Entra ID auth |
| `public_network_access_enabled` | conditional | Disabled when private endpoints enabled |

## Index Creation

Azure AI Search indexes **cannot be created via Terraform**. This project uses a postprovision hook:

### azure.yaml

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
set -e

SEARCH_SERVICE="${1:-aca-restapi-v2-search-mcpai}"
INDEX_NAME="${2:-documents}"

# Get Azure AD token (required when local_authentication_enabled = false)
ACCESS_TOKEN=$(az account get-access-token --resource "https://search.azure.com" --query "accessToken" -o tsv)

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X PUT \
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
    }')

if [[ "$HTTP_CODE" =~ ^(200|201|204)$ ]]; then
    echo "Index '$INDEX_NAME' created/updated successfully"
else
    echo "Failed to create index (HTTP $HTTP_CODE)"
    exit 1
fi
```

## RBAC Permissions

The Container App's managed identity needs:

```hcl
resource "azurerm_role_assignment" "container_app_search_reader" {
  scope                = azurerm_search_service.main.id
  role_definition_name = "Search Index Data Reader"
  principal_id         = azurerm_user_assigned_identity.main.principal_id
}

resource "azurerm_role_assignment" "container_app_search_contributor" {
  scope                = azurerm_search_service.main.id
  role_definition_name = "Search Index Data Contributor"
  principal_id         = azurerm_user_assigned_identity.main.principal_id
}
```

## SKU Options

| SKU | Replicas | Partitions | Use Case |
|-----|----------|------------|----------|
| `free` | 1 | 1 | Testing only |
| `basic` | 1-3 | 1 | Development, small workloads |
| `standard` | 1-12 | 1-12 | Production |

## Key Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `search_index_name` | string | `"documents"` | Name of the search index |

## Common Issues

| Issue | Solution |
|-------|----------|
| 401 on index creation | Use Azure AD bearer token, not API key |
| Index not found | Run `./scripts/create-search-index.sh` manually |
| 403 on queries | Add RBAC roles to the calling identity |
