# Container App
resource "azurerm_container_app" "main" {
  name                         = "${var.project_name}-ca-${var.environment}"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.main.id]
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
      name   = "api"
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest" # TODO: replace with built image
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
        name  = "AZURE_AI_SERVICES_DEPLOYMENT_GPT4O"
        value = var.enable_ai_foundry ? azurerm_cognitive_deployment.gpt4o[0].name : ""
      }
      env {
        name  = "AZURE_AI_SERVICES_DEPLOYMENT_GPT4O_MINI"
        value = var.enable_ai_foundry ? azurerm_cognitive_deployment.gpt4o_mini[0].name : ""
      }

      env {
        name  = "AZURE_SEARCH_SERVICE_ENDPOINT"
        value = "https://${azurerm_search_service.main.name}.search.windows.net"
      }
      env {
        name  = "AZURE_SEARCH_SERVICE_NAME"
        value = azurerm_search_service.main.name
      }
      env {
        name  = "APPLICATIONINSIGHTS_CONNECTION_STRING"
        value = azurerm_application_insights.main.connection_string
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
        name  = "OTEL_SERVICE_NAME"
        value = "${var.project_name}-api"
      }
      env {
        name  = "OTEL_SERVICE_VERSION"
        value = "1.0.0"
      }
      env {
        name  = "OTEL_RESOURCE_ATTRIBUTES"
        value = "service.name=${var.project_name}-api,service.version=1.0.0,deployment.environment=${var.environment}"
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
    external_enabled           = var.container_app_public
    target_port                = var.container_app_port

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  tags = var.tags

  # Retain depends_on if RBAC timing issues appear; removed for now to rely on implicit graph.
}
