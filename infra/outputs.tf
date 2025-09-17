############################
# Core Outputs
############################
output "resource_group_name" { value = azurerm_resource_group.main.name }
output "log_analytics_workspace_id" { value = azurerm_log_analytics_workspace.main.id }
output "application_insights_connection_string" {
  value     = azurerm_application_insights.main.connection_string
  sensitive = true
}
output "container_registry_login_server" { value = azurerm_container_registry.main.login_server }
output "CONTAINER_REGISTRY_LOGIN_SERVER" { value = azurerm_container_registry.main.login_server }
output "container_registry_admin_username" { value = azurerm_container_registry.main.admin_username }
output "managed_identity_client_id" { value = azurerm_user_assigned_identity.main.client_id }

############################
# AI Foundry & Cognitive
############################
output "ai_foundry_enabled" { value = var.enable_ai_foundry }
output "ai_foundry_hub_id" { value = var.enable_ai_foundry ? azurerm_ai_foundry.main[0].id : null }
output "ai_foundry_discovery_url" { value = var.enable_ai_foundry ? azurerm_ai_foundry.main[0].discovery_url : null }
output "ai_foundry_project_id" { value = var.enable_ai_foundry ? azurerm_ai_foundry_project.main[0].id : null }
output "key_vault_id" { value = var.enable_ai_foundry ? azurerm_key_vault.main[0].id : null }
output "storage_account_id" { value = var.enable_ai_foundry ? azurerm_storage_account.main[0].id : null }
output "ai_services_id" { value = var.enable_ai_foundry ? azurerm_cognitive_account.ai_services[0].id : null }
output "ai_services_endpoint" { value = var.enable_ai_foundry ? azurerm_cognitive_account.ai_services[0].endpoint : null }
output "gpt4o_deployment_id" { value = var.enable_ai_foundry ? azurerm_cognitive_deployment.gpt4o[0].name : null }
output "gpt4o_mini_deployment_id" { value = var.enable_ai_foundry ? azurerm_cognitive_deployment.gpt4o_mini[0].name : null }

############################
# Search
############################
output "search_service_url" { value = "https://${azurerm_search_service.main.name}.search.windows.net" }
output "search_service_name" { value = azurerm_search_service.main.name }

############################
# Networking / Private Endpoints
############################
output "private_endpoints_enabled" { value = var.enable_private_endpoints }
output "vnet_id" { value = var.enable_private_endpoints ? azurerm_virtual_network.main[0].id : null }
output "private_endpoint_subnet_id" { value = var.enable_private_endpoints ? azurerm_subnet.private_endpoints[0].id : null }
output "ai_foundry_private_endpoint_ip" {
  value = var.enable_private_endpoints && var.enable_ai_foundry && module.private_link_ai_foundry.created ? try(module.private_link_ai_foundry.private_endpoint_ips["hub"], null) : null
}
output "ai_services_private_endpoint_ip" {
  value = var.enable_private_endpoints && var.enable_ai_foundry && module.private_link_ai_services.created ? try(module.private_link_ai_services.private_endpoint_ips["openai"], null) : null
}
output "search_private_endpoint_ip" {
  value = var.enable_private_endpoints && module.private_link_search.created ? try(module.private_link_search.private_endpoint_ips["search"], null) : null
}
output "acr_private_endpoint_ip" {
  value = var.enable_private_endpoints && module.private_link_acr.created ? try(module.private_link_acr.private_endpoint_ips["acr"], null) : null
}

output "private_endpoints_all" {
  description = "Flattened list of all private endpoints created across modules"
  value = var.enable_private_endpoints ? concat(
    module.private_link_ai_foundry.created ? [for k, v in module.private_link_ai_foundry.private_endpoints : merge(v, { service_group = "ai_foundry", key = k })] : [],
    module.private_link_ai_services.created ? [for k, v in module.private_link_ai_services.private_endpoints : merge(v, { service_group = "ai_services", key = k })] : [],
    module.private_link_search.created ? [for k, v in module.private_link_search.private_endpoints : merge(v, { service_group = "search", key = k })] : [],
    module.private_link_acr.created ? [for k, v in module.private_link_acr.private_endpoints : merge(v, { service_group = "acr", key = k })] : []
  ) : []
}

############################
# Container Apps
############################
output "container_app_environment_id" { value = azurerm_container_app_environment.main.id }
output "container_app_id" { value = azurerm_container_app.main.id }
output "container_app_fqdn" { value = azurerm_container_app.main.latest_revision_fqdn }
output "container_app_url" { value = "https://${azurerm_container_app.main.latest_revision_fqdn}" }

############################
# Authentication
############################
output "authentication_enabled" {
  description = "Whether Container Apps authentication is enabled"
  value       = var.enable_container_app_auth
}
output "app_registration_created" {
  description = "Whether a new app registration was created"
  value       = var.enable_container_app_auth && var.create_app_registration
}
output "app_registration_client_id" {
  description = "Client ID of the app registration (created or existing)"
  value       = var.enable_container_app_auth ? (var.create_app_registration ? azuread_application.container_app_auth[0].client_id : var.existing_app_registration_client_id) : null
}
output "app_registration_object_id" {
  description = "Object ID of the created app registration"
  value       = var.enable_container_app_auth && var.create_app_registration ? azuread_application.container_app_auth[0].object_id : null
}
output "federated_credential_id" {
  description = "ID of the federated identity credential"
  value       = var.enable_container_app_auth && var.create_app_registration ? azuread_application_federated_identity_credential.container_app[0].id : null
}
output "authentication_redirect_uri" {
  description = "Authentication redirect URI for the container app"
  value       = var.enable_container_app_auth ? "https://${azurerm_container_app.main.latest_revision_fqdn}/.auth/login/aad/callback" : null
}

output "container_app_auth_config_id" {
  description = "Resource ID of the container app auth configuration (if managed in Terraform)"
  value       = var.enable_container_app_auth && length(azapi_resource.container_app_auth_config) > 0 ? azapi_resource.container_app_auth_config[0].id : null
}

