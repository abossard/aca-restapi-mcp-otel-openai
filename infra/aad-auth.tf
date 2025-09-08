# AAD Application & Federated Identity (conditional)
resource "azuread_application" "container_app_auth" {
  count        = var.enable_container_app_auth && var.create_app_registration ? 1 : 0
  display_name = local.app_registration_name

  web {
    # Use the actual Container App Environment default domain to build a correct redirect URI
    # Format: <app-name>.<env-default-domain>/.auth/login/aad/callback
    # Ensures no post-deploy patching is required and avoids redirect mismatch errors.
    redirect_uris = [
      "https://${var.project_name}-ca-${var.environment}.${azurerm_container_app_environment.main.default_domain}/.auth/login/aad/callback"
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

  # Use tenant ID in identifier URI to satisfy tenant policy requiring verified domain / tenant id
  identifier_uris = ["api://${data.azurerm_client_config.current.tenant_id}/${var.project_name}-${var.environment}"]

  tags = ["ContainerApp", "Authentication", "WorkloadIdentity"]
}

resource "azuread_service_principal" "container_app_auth" {
  count        = var.enable_container_app_auth && var.create_app_registration ? 1 : 0
  client_id    = azuread_application.container_app_auth[0].client_id
  use_existing = true
  tags         = ["ContainerApp", "Authentication", "WorkloadIdentity"]
}

resource "azuread_application_federated_identity_credential" "container_app" {
  count          = var.enable_container_app_auth && var.create_app_registration ? 1 : 0
  application_id = azuread_application.container_app_auth[0].id
  display_name   = "${local.app_registration_name}-federated"
  description    = "Federated identity credential for Azure Container Apps workload identity"

  audiences = ["api://AzureADTokenExchange"]
  issuer    = "https://login.microsoftonline.com/${data.azurerm_client_config.current.tenant_id}/v2.0"
  subject   = "system:serviceaccount:${var.project_name}:workload-identity-sa"
}

# Role assignment for the SP (Reader on RG)
resource "azurerm_role_assignment" "container_app_reader" {
  count                = var.enable_container_app_auth && var.create_app_registration ? 1 : 0
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Reader"
  principal_id         = azuread_service_principal.container_app_auth[0].object_id
}

# Additional AI permission if AI Foundry enabled
resource "azurerm_role_assignment" "container_app_ai_user" {
  count                = var.enable_container_app_auth && var.create_app_registration && var.enable_ai_foundry ? 1 : 0
  scope                = azurerm_cognitive_account.ai_services[0].id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = azuread_service_principal.container_app_auth[0].object_id
}

# -----------------------------------------------------------------------------
# Container App Authentication Configuration (via AzAPI - not yet in azurerm)
# Documentation: Uses Microsoft.App/containerApps/authConfigs (name must be 'current')
# -----------------------------------------------------------------------------
resource "azapi_resource" "container_app_auth_config" {
  count     = var.enable_container_app_auth ? 1 : 0
  type      = "Microsoft.App/containerApps/authConfigs@2023-05-01" # stable api version including authConfigs
  name      = "current"
  parent_id = azurerm_container_app.main.id

  # Build the full ARM body. If using an existing app registration with client secret, we rely on secret already set via container app block.
  body = jsonencode({
    properties = {
      platform = {
        enabled        = true
        runtimeVersion = "~1"
      }
      globalValidation = merge(
        {
          unauthenticatedClientAction = var.container_app_auth_unauthenticated_action
        },
        var.container_app_auth_require_authentication ? { redirectToProvider = "AzureActiveDirectory" } : {}
      )
      identityProviders = {
        azureActiveDirectory = {
          enabled = true
          registration = merge({
            openIdIssuer = "https://login.microsoftonline.com/${data.azurerm_client_config.current.tenant_id}/v2.0"
            clientId     = local.auth_client_id
          }, var.create_app_registration ? {} : (
            var.existing_app_registration_client_secret != "" ? {
              clientSecretSettingName = "MICROSOFT_PROVIDER_AUTHENTICATION_SECRET"
            } : {}
          ))
          validation = {
            allowedAudiences = local.auth_allowed_audiences
          }
        }
      }
    }
  })

  lifecycle {
    ignore_changes = [body] # Avoid perpetual diffs if platform adds defaults; remove if strict drift desired
  }

  depends_on = [
    azurerm_container_app.main,
    azuread_application.container_app_auth,
    azuread_application_federated_identity_credential.container_app
  ]
}
