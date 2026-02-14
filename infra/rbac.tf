# RBAC Role Assignments
# Optional local developer RBAC convenience assignments
data "azurerm_client_config" "current_user" {}

resource "azurerm_role_assignment" "local_dev_rg_owner" {
  count                = var.local_dev_rbac ? 1 : 0
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Owner"
  principal_id         = local.local_developer_object_id
}

resource "azurerm_role_assignment" "local_dev_acr_pull" {
  count                = var.local_dev_rbac ? 1 : 0
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = local.local_developer_object_id
}

resource "azurerm_role_assignment" "local_dev_kv_admin" {
  count                = var.local_dev_rbac && var.enable_ai_foundry ? 1 : 0
  scope                = azurerm_key_vault.main[0].id
  role_definition_name = "Key Vault Administrator"
  principal_id         = local.local_developer_object_id
}

resource "azurerm_role_assignment" "local_dev_search_contrib" {
  count                = var.local_dev_rbac ? 1 : 0
  scope                = azurerm_search_service.main.id
  role_definition_name = "Search Service Contributor"
  principal_id         = local.local_developer_object_id
}

resource "azurerm_role_assignment" "local_dev_search_index_data_contributor" {
  count                = var.local_dev_rbac ? 1 : 0
  scope                = azurerm_search_service.main.id
  role_definition_name = "Search Index Data Contributor"
  principal_id         = local.local_developer_object_id
}

resource "azurerm_role_assignment" "local_dev_search_index_data_reader" {
  count                = var.local_dev_rbac ? 1 : 0
  scope                = azurerm_search_service.main.id
  role_definition_name = "Search Index Data Reader"
  principal_id         = local.local_developer_object_id
}

resource "azurerm_role_assignment" "local_dev_cognitive_user" {
  count                = var.local_dev_rbac && var.enable_ai_foundry ? 1 : 0
  scope                = azurerm_cognitive_account.ai_services[0].id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = local.local_developer_object_id
}

resource "azurerm_role_assignment" "local_dev_cognitive_contributor" {
  count                = var.local_dev_rbac && var.enable_ai_foundry ? 1 : 0
  scope                = azurerm_cognitive_account.ai_services[0].id
  role_definition_name = "Cognitive Services Contributor"
  principal_id         = local.local_developer_object_id
}

resource "azurerm_role_assignment" "local_dev_storage_blob_data_contributor" {
  count                = var.local_dev_rbac && var.enable_ai_foundry ? 1 : 0
  scope                = azurerm_storage_account.main[0].id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = local.local_developer_object_id
}
# AI Foundry Roles
resource "azurerm_role_assignment" "ai_foundry_data_scientist" {
  count                = var.enable_ai_foundry ? 1 : 0
  scope                = azurerm_ai_foundry.main[0].id
  role_definition_name = "AzureML Data Scientist"
  principal_id         = azurerm_user_assigned_identity.main.principal_id
}

resource "azurerm_role_assignment" "ai_foundry_compute_operator" {
  count                = var.enable_ai_foundry ? 1 : 0
  scope                = azurerm_ai_foundry.main[0].id
  role_definition_name = "AzureML Compute Operator"
  principal_id         = azurerm_user_assigned_identity.main.principal_id
}

# Search Roles
resource "azurerm_role_assignment" "search_contributor" {
  scope                = azurerm_search_service.main.id
  role_definition_name = "Search Service Contributor"
  principal_id         = azurerm_user_assigned_identity.main.principal_id
}

resource "azurerm_role_assignment" "search_index_data_contributor" {
  scope                = azurerm_search_service.main.id
  role_definition_name = "Search Index Data Contributor"
  principal_id         = azurerm_user_assigned_identity.main.principal_id
}

resource "azurerm_role_assignment" "search_service_storage_blob_reader" {
  count                = local.search_ingestion_enabled ? 1 : 0
  scope                = azurerm_storage_account.main[0].id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_search_service.main.identity[0].principal_id
}

resource "azurerm_role_assignment" "search_service_openai_user" {
  count                = local.search_ingestion_enabled ? 1 : 0
  scope                = azurerm_cognitive_account.ai_services[0].id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = azurerm_search_service.main.identity[0].principal_id
}

# Key Vault
resource "azurerm_role_assignment" "key_vault_secrets_user" {
  count                = var.enable_ai_foundry ? 1 : 0
  scope                = azurerm_key_vault.main[0].id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.main.principal_id
}

# Storage
resource "azurerm_role_assignment" "storage_blob_data_contributor" {
  count                = var.enable_ai_foundry ? 1 : 0
  scope                = azurerm_storage_account.main[0].id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.main.principal_id
}

# Cognitive Services
resource "azurerm_role_assignment" "ai_services_contributor" {
  count                = var.enable_ai_foundry ? 1 : 0
  scope                = azurerm_cognitive_account.ai_services[0].id
  role_definition_name = "Cognitive Services Contributor"
  principal_id         = azurerm_user_assigned_identity.main.principal_id
}

resource "azurerm_role_assignment" "ai_services_openai_user" {
  count                = var.enable_ai_foundry ? 1 : 0
  scope                = azurerm_cognitive_account.ai_services[0].id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = azurerm_user_assigned_identity.main.principal_id
}

# Application Insights telemetry ingestion via Entra ID (used when local auth is disabled).
resource "azurerm_role_assignment" "app_insights_metrics_publisher" {
  scope                = azurerm_application_insights.main.id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = azurerm_user_assigned_identity.main.principal_id
}
