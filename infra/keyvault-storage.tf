# Key Vault & Storage (AI Foundry dependency)
resource "azurerm_key_vault" "main" {
  count                       = var.enable_ai_foundry ? 1 : 0
  # Key Vault name constraints: 3-24 chars, alphanumeric and dashes only. Remove dashes from project base, append -kv plus suffix.
  # Example result: acarestapimcp-kvabc123xy (<=24).
  name                        = substr(replace(var.project_name, "-", ""), 0, 16) == replace(var.project_name, "-", "") ? "${substr(replace(var.project_name, "-", ""), 0, 16)}-kv${substr(random_string.unique.result,0,2)}" : "${substr(replace(var.project_name, "-", ""), 0, 16)}-kv${substr(random_string.unique.result,0,2)}"
  location                    = azurerm_resource_group.main.location
  resource_group_name         = azurerm_resource_group.main.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  purge_protection_enabled    = true
  soft_delete_retention_days  = 7

  # Switch to RBAC-only (no access policy) for principle of least privilege; access via role assignments.
  rbac_authorization_enabled = true

  tags = var.tags
}

resource "azurerm_storage_account" "main" {
  count                            = var.enable_ai_foundry ? 1 : 0
  # Ensure uniqueness: include first 4 chars of random suffix
  name                             = lower(substr(replace(var.project_name, "-", ""),0,16))
  resource_group_name              = azurerm_resource_group.main.name
  location                         = azurerm_resource_group.main.location
  account_tier                     = "Standard"
  account_replication_type         = "LRS"
  allow_nested_items_to_be_public  = false
  # Entra ID only auth: disable shared keys & default to OAuth
  shared_access_key_enabled        = false
  default_to_oauth_authentication  = true
  queue_encryption_key_type        = "Account"
  table_encryption_key_type        = "Account"
  public_network_access_enabled    = true
  min_tls_version                  = "TLS1_2"
  is_hns_enabled                   = false
  tags                             = var.tags
}
