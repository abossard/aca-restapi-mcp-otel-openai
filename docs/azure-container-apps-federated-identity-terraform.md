# Azure Container Apps Authentication with Federated Identity using Terraform

This document provides comprehensive guidance for creating an Azure AD App Registration with federated trust for Azure Container Apps authentication using Terraform.

## Overview

Workload identity federation enables Azure Container Apps to authenticate with Azure AD without managing secrets or certificates. This approach uses short-lived tokens and eliminates the security risks associated with storing credentials.

## Key Concepts

### Federated Identity Credentials
- **Purpose**: Create trust relationships between external identity providers and Azure AD applications
- **Benefit**: Eliminates need for client secrets or certificates
- **Limit**: Maximum of 20 federated identity credentials per application
- **Audience**: Recommended value is `api://AzureADTokenExchange`

### Required Components
1. **Azure AD App Registration**: The application that will receive tokens
2. **Federated Identity Credential**: The trust relationship configuration
3. **Container Apps Authentication**: Built-in authentication feature

## Terraform Configuration

### Required Providers

```hcl
terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.29.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.40.0"
    }
  }
}
```

### 1. Create Azure AD App Registration

```hcl
# Create the Azure AD Application
resource "azuread_application" "container_app_auth" {
  display_name = "${var.project_name}-container-app-${var.environment}"
  
  # Configure for web application
  web {
    redirect_uris = ["https://${var.container_app_fqdn}/.auth/login/aad/callback"]
    implicit_grant {
      access_token_issuance_enabled = true
      id_token_issuance_enabled     = true
    }
  }
  
  # Required API permissions
  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph
    
    resource_access {
      id   = "e1fe6dd8-ba31-4d61-89e7-88639da4683d" # User.Read
      type = "Scope"
    }
  }
  
  tags = ["ContainerApp", "Authentication", "WorkloadIdentity"]
}

# Create service principal for the application
resource "azuread_service_principal" "container_app_auth" {
  application_id = azuread_application.container_app_auth.application_id
  
  tags = ["ContainerApp", "Authentication", "WorkloadIdentity"]
}
```

### 2. Configure Federated Identity Credential

```hcl
# Federated identity credential for Container Apps
resource "azuread_application_federated_identity_credential" "container_app" {
  application_object_id = azuread_application.container_app_auth.object_id
  display_name         = "${var.project_name}-container-app-federated-${var.environment}"
  description          = "Federated identity credential for Azure Container Apps workload identity"
  
  # Container Apps OIDC configuration
  audiences = ["api://AzureADTokenExchange"]
  issuer    = var.container_apps_oidc_issuer_url
  subject   = "system:serviceaccount:${var.kubernetes_namespace}:${var.service_account_name}"
}
```

### 3. Container Apps Authentication Configuration

```hcl
# Container App with authentication
resource "azurerm_container_app" "main" {
  name                         = "${var.project_name}-ca-${var.environment}"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"
  
  # Configure authentication
  auth_settings {
    enabled = true
    
    active_directory {
      client_id                = azuread_application.container_app_auth.application_id
      tenant_auth_endpoint     = "https://login.microsoftonline.com/${data.azurerm_client_config.current.tenant_id}/v2.0"
      allowed_audiences        = ["api://${azuread_application.container_app_auth.application_id}"]
      client_secret_setting_name = null # No secret needed with federated identity
    }
    
    # Authentication behavior
    unauthenticated_client_action = "RedirectToLoginPage"
    default_provider             = "AzureActiveDirectory"
    
    # Token store configuration
    token_store_enabled = true
  }
  
  # Container configuration with workload identity
  template {
    min_replicas = 0
    max_replicas = 1
    
    container {
      name   = "api"
      image  = var.container_image
      cpu    = 0.25
      memory = "0.5Gi"
      
      # Workload identity environment variables
      env {
        name  = "AZURE_CLIENT_ID"
        value = azuread_application.container_app_auth.application_id
      }
      
      env {
        name  = "AZURE_TENANT_ID"
        value = data.azurerm_client_config.current.tenant_id
      }
      
      env {
        name  = "AZURE_FEDERATED_TOKEN_FILE"
        value = "/var/run/secrets/azure/tokens/azure-identity-token"
      }
    }
  }
  
  # Public ingress
  ingress {
    allow_insecure_connections = false
    external_enabled           = true
    target_port               = 8000
    
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
  
  tags = var.tags
}
```

### 4. RBAC Permissions

```hcl
# Assign necessary permissions to the app registration's service principal
resource "azurerm_role_assignment" "container_app_reader" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Reader"
  principal_id         = azuread_service_principal.container_app_auth.object_id
}

# Additional permissions for AI services
resource "azurerm_role_assignment" "container_app_ai_user" {
  count                = var.enable_ai_foundry ? 1 : 0
  scope                = azurerm_cognitive_account.ai_services[0].id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = azuread_service_principal.container_app_auth.object_id
}
```

## Alternative Approach: User-Assigned Managed Identity

For simpler scenarios, you can use a User-Assigned Managed Identity with federated credentials:

```hcl
# User-assigned managed identity
resource "azurerm_user_assigned_identity" "container_app" {
  location            = azurerm_resource_group.main.location
  name                = "${var.project_name}-container-identity-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  
  tags = var.tags
}

# Federated identity credential for the managed identity
resource "azurerm_federated_identity_credential" "container_app" {
  name                = "${var.project_name}-container-federated-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  audience           = ["api://AzureADTokenExchange"]
  issuer             = var.container_apps_oidc_issuer_url
  parent_id          = azurerm_user_assigned_identity.container_app.id
  subject            = "system:serviceaccount:${var.kubernetes_namespace}:${var.service_account_name}"
}
```

## Variables Configuration

```hcl
variable "container_apps_oidc_issuer_url" {
  description = "OIDC issuer URL for the Container Apps environment"
  type        = string
  default     = "https://your-container-apps-environment.oidc.issuer.url"
}

variable "kubernetes_namespace" {
  description = "Kubernetes namespace for the service account"
  type        = string
  default     = "default"
}

variable "service_account_name" {
  description = "Name of the Kubernetes service account"
  type        = string
  default     = "workload-identity-sa"
}

variable "container_app_fqdn" {
  description = "Fully qualified domain name of the container app"
  type        = string
}
```

## Outputs

```hcl
output "app_registration_client_id" {
  description = "Client ID of the created app registration"
  value       = azuread_application.container_app_auth.application_id
}

output "app_registration_object_id" {
  description = "Object ID of the created app registration"
  value       = azuread_application.container_app_auth.object_id
}

output "federated_credential_id" {
  description = "ID of the federated identity credential"
  value       = azuread_application_federated_identity_credential.container_app.id
}

output "container_app_auth_endpoint" {
  description = "Authentication endpoint for the container app"
  value       = "https://${azurerm_container_app.main.latest_revision_fqdn}/.auth/login/aad/callback"
}
```

## Key Configuration Parameters

### Federated Identity Credential Parameters
- **`issuer`**: URL of the external identity provider (Container Apps OIDC endpoint)
- **`subject`**: Identifier format: `system:serviceaccount:${namespace}:${service_account_name}`
- **`audiences`**: Must be `["api://AzureADTokenExchange"]`
- **`display_name`**: Unique name (3-120 characters, URL-friendly)

### Container Apps Authentication Parameters
- **`client_id`**: Application ID from the app registration
- **`tenant_auth_endpoint`**: Azure AD tenant endpoint
- **`allowed_audiences`**: API identifier for the application
- **`unauthenticated_client_action`**: Behavior for unauthenticated users

## Security Considerations

1. **No Secrets**: Federated identity eliminates the need for client secrets
2. **Short-lived Tokens**: Authentication uses temporary tokens
3. **Principle of Least Privilege**: Assign minimal required permissions
4. **Audience Validation**: Use specific audience values for token validation
5. **Subject Matching**: Ensure exact subject identifier matching

## Troubleshooting

### Common Issues
1. **Subject Mismatch**: Verify the subject identifier format matches exactly
2. **Audience Configuration**: Ensure audiences parameter uses correct values
3. **OIDC Issuer URL**: Validate the Container Apps OIDC issuer URL
4. **Permission Errors**: Check RBAC assignments for the service principal

### Debugging Steps
1. Verify app registration configuration in Azure portal
2. Check federated credential settings
3. Validate Container Apps authentication logs
4. Test token exchange manually using Azure CLI

## References and Sources

### Official Documentation
- [Authentication and authorization in Azure Container Apps](https://learn.microsoft.com/en-us/azure/container-apps/authentication) - Microsoft Learn
- [Enable authentication and authorization in Azure Container Apps with Microsoft Entra ID](https://learn.microsoft.com/en-us/azure/container-apps/authentication-entra) - Microsoft Learn
- [Create a trust relationship between an app and an external identity provider](https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation-create-trust) - Microsoft Learn
- [Workload Identity Federation](https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation) - Microsoft Learn

### Terraform Documentation
- [azuread_application_federated_identity_credential](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/application_federated_identity_credential) - Terraform Registry
- [azurerm_federated_identity_credential](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/federated_identity_credential) - Terraform Registry
- [azuread_application](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/application) - Terraform Registry

### Implementation Examples
- [Introduction to Azure DevOps Workload identity federation (OIDC) with Terraform](https://devblogs.microsoft.com/devops/introduction-to-azure-devops-workload-identity-federation-oidc-with-terraform/) - Azure DevOps Blog
- [Using Azure DevOps Pipelines Workload identity federation (OIDC) with Azure for Terraform Deployments](https://learn.microsoft.com/en-us/samples/azure-samples/azure-devops-terraform-oidc-ci-cd/azure-devops-terraform-oidc-ci-cd/) - Microsoft Learn Samples
- [Use dynamic credentials with the Azure provider in HCP Terraform](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/dynamic-provider-credentials/azure-configuration) - HashiCorp Developer

### Community Resources
- [Workload identity federation for Azure DevOps with Terraform](https://blog.xmi.fr/posts/azure-devops-terraform-oidc/) - Xavier Mignot Blog
- [Integrating Terraform with OIDC and Workload Identity Federation in Azure DevOps](https://blog.cellenza.com/en/software-development/integrating-terraform-with-oidc-and-workload-identity-federation-in-azure-devops/) - Cellenza Blog
- [Azure Federated Identity Credentials for GitHub](https://mattias.engineer/blog/2024/azure-federated-credentials-github/) - Mattias.engineer

## Best Practices

1. **Use Terraform Provider v3.40.0+**: Avoid failures when creating multiple federated identity credentials
2. **Separate Credentials for Different Phases**: Create separate federated identity credentials for plan and apply phases in CI/CD
3. **Descriptive Naming**: Use clear, descriptive names for federated credentials
4. **Minimal Permissions**: Assign only the minimum required RBAC permissions
5. **Environment Separation**: Use different app registrations for different environments
6. **Token Validation**: Implement proper token validation in your application code

This configuration enables secure, secret-free authentication for Azure Container Apps using workload identity federation with Terraform.