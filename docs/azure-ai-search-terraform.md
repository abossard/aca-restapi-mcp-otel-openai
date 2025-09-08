# Azure AI Search Terraform Configuration

This document provides examples for creating Azure AI Search resources using Terraform.

## Basic Configuration

Use `azurerm_search_service` for creating Azure AI Search:

```hcl
resource "azurerm_search_service" "main" {
  name                = "${var.project_name}-search-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "basic"
  replica_count       = 1
  partition_count     = 1
  
  # Optional: Enable managed identity
  identity {
    type = "SystemAssigned"
  }
  
  tags = var.tags
}
```

## SKU Options and Scaling

Different SKU tiers with scaling capabilities:

```hcl
# Development/Testing
resource "azurerm_search_service" "dev" {
  name                = "${var.project_name}-search-dev"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "free"
  # free tier doesn't support replicas/partitions
  
  tags = var.tags
}

# Production with high availability
resource "azurerm_search_service" "prod" {
  name                = "${var.project_name}-search-prod"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "standard"
  replica_count       = 2  # Min 2 for HA
  partition_count     = 3  # For document scaling
  
  identity {
    type = "SystemAssigned"
  }
  
  # Optional: Network security
  public_network_access_enabled = false
  
  tags = var.tags
}
```

## Security Configuration

Enable private endpoints and disable public access:

```hcl
resource "azurerm_search_service" "secure" {
  name                = "${var.project_name}-search-secure"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "standard"
  replica_count       = 1
  partition_count     = 1
  
  # Security settings
  public_network_access_enabled = false
  
  # Authentication
  identity {
    type = "SystemAssigned"
  }
  
  tags = var.tags
}
```

## Outputs

```hcl
output "search_service_name" {
  value = azurerm_search_service.main.name
}

output "search_service_url" {
  value = "https://${azurerm_search_service.main.name}.search.windows.net"
}

output "search_primary_key" {
  value     = azurerm_search_service.main.primary_key
  sensitive = true
}

output "search_query_keys" {
  value     = azurerm_search_service.main.query_keys
  sensitive = true
}
```

## Validation Constraints

Important validation rules:
- **replica_count**: Must be between 1 and 12
- **partition_count**: Must be one of: 1, 2, 3, 4, 6, 12
- **Free tier**: Doesn't support replicas/partitions
- **High Availability**: Requires minimum 2 replicas

## Variables Example

```hcl
variable "search_sku" {
  description = "Azure Search service tier"
  type        = string
  default     = "basic"
  validation {
    condition     = contains(["free", "basic", "standard", "standard2", "standard3"], var.search_sku)
    error_message = "SKU must be one of: free, basic, standard, standard2, standard3."
  }
}

variable "search_replicas" {
  description = "Number of replicas for high availability"
  type        = number
  default     = 1
  validation {
    condition     = var.search_replicas >= 1 && var.search_replicas <= 12
    error_message = "Replica count must be between 1 and 12."
  }
}

variable "search_partitions" {
  description = "Number of partitions for scaling"
  type        = number
  default     = 1
  validation {
    condition     = contains([1, 2, 3, 4, 6, 12], var.search_partitions)
    error_message = "Partition count must be one of: 1, 2, 3, 4, 6, 12."
  }
}
```

## Important Notes

- Index creation via Terraform is not currently supported (use REST API post-deployment)
- Services created after April 2024 have larger partitions and higher vector quotas
- Use managed identity for secure authentication in production
- For 1GB capacity with 10k documents, basic tier should be sufficient