# Container App

locals {
  container_image_revision_trimmed = trimspace(var.container_image_revision)
  container_image_has_registry     = local.container_image_revision_trimmed != "" && can(regex("/", local.container_image_revision_trimmed))
  resolved_acr_image_reference = local.container_image_revision_trimmed == "" ? "" : (
    local.container_image_has_registry
    ? local.container_image_revision_trimmed
    : format("%s/%s", azurerm_container_registry.main.login_server, local.container_image_revision_trimmed)
  )
  using_acr_image           = var.use_acr_image && local.resolved_acr_image_reference != ""
  fallback_container_image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
  effective_container_image = local.using_acr_image ? local.resolved_acr_image_reference : local.fallback_container_image
}

resource "azurerm_container_app" "main" {
  name                         = "${var.project_name}-ca-${var.environment}"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.main.id]
  }

  # Container Registry authentication via User Assigned Managed Identity
  # Without this block the revision will fail to pull images from ACR (UNAUTHORIZED) when admin user/password is disabled.
  dynamic "registry" {
    for_each = var.use_acr_image ? [1] : []
    content {
      server   = azurerm_container_registry.main.login_server
      identity = azurerm_user_assigned_identity.main.id
    }
  }

  dynamic "secret" {
    for_each = var.enable_container_app_auth && !var.create_app_registration && var.existing_app_registration_client_secret != "" ? [1] : []
    content {
      name  = "microsoft-provider-secret"
      value = var.existing_app_registration_client_secret
    }
  }

  template {
    min_replicas = 0
    max_replicas = 1

    container {
      name = "api"
      # Automatically use the ACR image only when a revision reference is supplied via env/variable
      image  = local.effective_container_image
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "AZURE_AI_FOUNDRY_DISCOVERY_URL"
        value = var.enable_ai_foundry ? azurerm_ai_foundry.main[0].discovery_url : ""
      }
      env {
        name  = "AZURE_AI_FOUNDRY_PROJECT_ID"
        value = var.enable_ai_foundry ? azurerm_ai_foundry_project.main[0].project_id : ""
      }
      env {
        name  = "AZURE_AI_SERVICES_ENDPOINT"
        value = var.enable_ai_foundry ? azurerm_cognitive_account.ai_services[0].endpoint : ""
      }
      env {
        name  = "AZURE_OPENAI_ENDPOINT"
        value = var.enable_ai_foundry ? azurerm_cognitive_account.ai_services[0].endpoint : ""
      }
      env {
        name  = "AZURE_AI_SERVICES_DEPLOYMENT_GPT4O"
        value = var.enable_ai_foundry ? azurerm_cognitive_deployment.gpt4o[0].name : ""
      }
      env {
        name  = "AZURE_AI_SERVICES_DEPLOYMENT_GPT4O_MINI"
        value = var.enable_ai_foundry ? azurerm_cognitive_deployment.gpt4o_mini[0].name : ""
      }
  
      env {
        name  = "APPLICATIONINSIGHTS_CONNECTION_STRING"
        value = azurerm_application_insights.main.connection_string
      }
      
      env {
        name  = "AZURE_SEARCH_SERVICE_ENDPOINT"
        value = "https://${azurerm_search_service.main.name}.search.windows.net"
      }
      env {
        name  = "AZURE_SEARCH_ENDPOINT"
        value = "https://${azurerm_search_service.main.name}.search.windows.net"
      }
      env {
        name  = "AZURE_SEARCH_SERVICE_NAME"
        value = azurerm_search_service.main.name
      }
      env {
        name  = "AZURE_SEARCH_INDEX"
        value = var.search_index_name
      }
      env {
        name  = "AZURE_KEY_VAULT_URL"
        value = var.enable_ai_foundry ? azurerm_key_vault.main[0].vault_uri : ""
      }

      env {
        name  = "ENVIRONMENT"
        value = var.environment
      }
      env {
        name  = "PROJECT_NAME"
        value = var.project_name
      }
      env {
        name  = "PYTHONUNBUFFERED"
        value = "1"
      }
      env {
        name  = "PORT"
        value = tostring(var.container_app_port)
      }
      env {
        name  = "AZURE_CLIENT_ID"
        value = azurerm_user_assigned_identity.main.client_id
      }

      dynamic "env" {
        for_each = var.enable_container_app_auth && !var.create_app_registration ? [1] : []
        content {
          name        = "MICROSOFT_PROVIDER_AUTHENTICATION_SECRET"
          secret_name = "microsoft-provider-secret"
        }
      }

      dynamic "env" {
        for_each = var.enable_container_app_auth ? [1] : []
        content {
          name  = "MICROSOFT_PROVIDER_CLIENT_ID"
          value = var.create_app_registration ? azuread_application.container_app_auth[0].client_id : var.existing_app_registration_client_id
        }
      }
    }

    http_scale_rule {
      name                = "http-rule"
      concurrent_requests = 10
    }
  }

  ingress {
    allow_insecure_connections = false
    # Controlled by variable to allow private (internal) only exposure when set to false
    external_enabled = var.container_app_public
    target_port      = var.container_app_port

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  # Add azd-service-name so Azure Developer CLI (azd) can map this Container App to the 'api' service in azure.yaml
  tags = merge(var.tags, {
    "azd-service-name" = "api"
  })

  # Retain depends_on if RBAC timing issues appear; removed for now to rely on implicit graph.
}
