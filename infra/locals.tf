locals {
  env_name_lower    = lower(var.environment_name)
  env_token_raw     = replace(lower(var.environment_name), "/[^a-z0-9]/", "")
  project_token_raw = replace(lower(var.project_name), "/[^a-z0-9]/", "")

  # Keep simple short env names unchanged for stability.
  # Add hash for long names or names that normalize (for example, contain '-' or '_') to reduce collisions.
  env_token_base = local.env_token_raw != "" ? local.env_token_raw : "env"
  env_token = length(local.env_token_base) <= 8 && local.env_token_base == local.env_name_lower ? local.env_token_base : format(
    "%s%s",
    substr(local.env_token_base, 0, 4),
    substr(md5(local.env_name_lower), 0, 4)
  )
  project_token = substr(local.project_token_raw != "" ? local.project_token_raw : "proj", 0, 6)
  name_base     = substr("${local.env_token}${local.project_token}", 0, 12)
  unique_suffix = substr(random_string.unique.result, 0, 4)

  # Shared short names
  resource_group_name              = "rg-${local.env_token}"
  user_assigned_identity_name      = "${local.env_token}-id"
  log_analytics_workspace_name     = "law-${local.env_token}-${local.unique_suffix}"
  app_insights_name                = "appi-${local.env_token}-${local.unique_suffix}"
  virtual_network_name             = "${local.env_token}-vnet"
  private_endpoint_subnet_name     = "${local.env_token}-pesn"
  container_apps_infra_subnet_name = "${local.env_token}-acasn"
  container_app_environment_name   = "${local.env_token}-cae"
  container_app_name               = "${local.env_token}-ca"
  key_vault_name                   = substr("kv-${local.name_base}-${local.unique_suffix}", 0, 24)
  storage_account_name             = substr("sa${local.name_base}${local.unique_suffix}", 0, 24)
  ai_foundry_name                  = "aif-${local.name_base}-${local.unique_suffix}"
  ai_foundry_project_name          = "aip-${local.name_base}-${local.unique_suffix}"
  ai_services_name                 = "aoai-${local.name_base}-${local.unique_suffix}"
  search_service_name              = "srch-${local.name_base}-${local.unique_suffix}"
  container_registry_name          = substr("acr${local.name_base}${local.unique_suffix}", 0, 50)
  cognitive_custom_subdomain_name  = "aoai-${local.name_base}-${local.unique_suffix}"
  search_data_source_name          = "ds-${local.env_token}-${local.unique_suffix}"
  search_skillset_name             = "sk-${local.env_token}-${local.unique_suffix}"
  search_indexer_name              = "ixr-${local.env_token}-${local.unique_suffix}"
  search_vectorizer_name           = "vz-${local.env_token}-${local.unique_suffix}"
  search_vector_profile_name       = "vp-${local.env_token}-${local.unique_suffix}"
  search_vector_algorithm_name     = "va-${local.env_token}-${local.unique_suffix}"
  search_data_plane_parent_id      = "${azurerm_search_service.main.name}.search.windows.net"
  local_developer_object_id        = var.local_developer_principal_object_id != "" ? var.local_developer_principal_object_id : data.azurerm_client_config.current_user.object_id
  search_ingestion_enabled         = var.enable_search_managed_ingestion && var.enable_ai_foundry

  private_link_prefix_ai_foundry  = "${local.env_token}-aif"
  private_link_prefix_ai_services = "${local.env_token}-aoai"
  private_link_prefix_search      = "${local.env_token}-srch"
  private_link_prefix_acr         = "${local.env_token}-acr"

  app_registration_name = var.app_registration_name != "" ? var.app_registration_name : "${local.env_token}-auth-${local.unique_suffix}"
  auth_client_id        = var.enable_container_app_auth ? (var.create_app_registration ? azuread_application.container_app_auth[0].client_id : var.existing_app_registration_client_id) : null
  auth_allowed_audiences = length(var.container_app_auth_allowed_audiences) > 0 ? var.container_app_auth_allowed_audiences : (
    local.auth_client_id != null ? ["api://${local.auth_client_id}"] : []
  )
}
