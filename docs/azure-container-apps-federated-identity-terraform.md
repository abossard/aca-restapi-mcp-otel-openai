# Azure Container Apps Authentication with Federated Identity

This document describes the Container Apps authentication setup using Terraform with federated identity credentials (secretless).

## Overview

This project uses:
- **Entra ID App Registration** with federated identity (no client secrets)
- **Container Apps built-in auth** via AzAPI resource
- **Automatic redirect** for unauthenticated users

## Implementation

### App Registration

```hcl
resource "azuread_application" "container_app_auth" {
  count        = var.enable_container_app_auth && var.create_app_registration ? 1 : 0
  display_name = local.app_registration_name

  web {
    redirect_uris = [
      "https://${var.project_name}-ca-${var.environment_name}.${azurerm_container_app_environment.main.default_domain}/.auth/login/aad/callback"
    ]
    implicit_grant {
      access_token_issuance_enabled = true
      id_token_issuance_enabled     = true
    }
  }

  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph
    resource_access {
      id   = "e1fe6dd8-ba31-4d61-89e7-88639da4683d" # User.Read
      type = "Scope"
    }
  }

  identifier_uris = ["api://${data.azurerm_client_config.current.tenant_id}/${var.project_name}-${var.environment_name}"]
}
```

### Federated Identity Credential

```hcl
resource "azuread_application_federated_identity_credential" "container_app" {
  count          = var.enable_container_app_auth && var.create_app_registration ? 1 : 0
  application_id = azuread_application.container_app_auth[0].id
  display_name   = "${local.app_registration_name}-federated"
  description    = "Federated identity for Container Apps workload identity"

  audiences = ["api://AzureADTokenExchange"]
  issuer    = "https://login.microsoftonline.com/${data.azurerm_client_config.current.tenant_id}/v2.0"
  subject   = "system:serviceaccount:${var.project_name}:workload-identity-sa"
}
```

### Auth Config (via AzAPI)

```hcl
resource "azapi_resource" "container_app_auth_config" {
  count     = var.enable_container_app_auth ? 1 : 0
  type      = "Microsoft.App/containerApps/authConfigs@2023-05-01"
  name      = "current"
  parent_id = azurerm_container_app.main.id

  body = jsonencode({
    properties = {
      platform = {
        enabled        = true
        runtimeVersion = "~1"
      }
      globalValidation = {
        unauthenticatedClientAction = var.container_app_auth_unauthenticated_action
        redirectToProvider          = "AzureActiveDirectory"
      }
      identityProviders = {
        azureActiveDirectory = {
          enabled = true
          registration = {
            openIdIssuer = "https://login.microsoftonline.com/${data.azurerm_client_config.current.tenant_id}/v2.0"
            clientId     = local.auth_client_id
          }
          validation = {
            allowedAudiences = local.auth_allowed_audiences
          }
        }
      }
    }
  })
}
```

## Key Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `enable_container_app_auth` | bool | `true` | Enable authentication |
| `create_app_registration` | bool | `true` | Create new app reg (federated) |
| `container_app_auth_unauthenticated_action` | string | `RedirectToLoginPage` | Behavior for unauth requests |
| `existing_app_registration_client_id` | string | `""` | Use existing app reg |
| `existing_app_registration_client_secret` | string | `""` | Secret for existing app reg |

## Deployment Options

### Option 1: New App Registration (Recommended)

```hcl
enable_container_app_auth = true
create_app_registration   = true
```

Creates federated identity - no secrets needed.

### Option 2: Existing App Registration

```hcl
enable_container_app_auth              = true
create_app_registration                = false
existing_app_registration_client_id    = "your-client-id"
existing_app_registration_client_secret = "your-secret"
```

## Authentication Flow

1. User accesses Container App URL
2. Auth middleware redirects to Entra ID
3. User authenticates
4. Entra ID redirects back with token
5. App receives authenticated request

## Accessing User Info

```python
from fastapi import Request

@app.get("/user")
async def get_user(request: Request):
    return {
        "user": request.headers.get("x-ms-client-principal-name"),
        "user_id": request.headers.get("x-ms-client-principal-id"),
    }
```

## Common Issues

| Issue | Solution |
|-------|----------|
| Redirect URI mismatch | Check app reg redirect URIs match Container App FQDN |
| 401 after login | Verify allowed audiences |
| Token not issued | Wait for federated credential propagation (~2 min) |

## Security Benefits

- **No secrets**: Federated identity eliminates client secrets
- **Short-lived tokens**: Automatic token refresh
- **Built-in auth**: No application code changes required
