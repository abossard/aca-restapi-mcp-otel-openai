# Key Vault & Storage (AI Foundry dependency)
resource "azurerm_key_vault" "main" {
  count = var.enable_ai_foundry ? 1 : 0
  # Key Vault names are globally unique; short base + random suffix avoids collisions.
  name                       = local.key_vault_name
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  purge_protection_enabled   = false
  soft_delete_retention_days = 7

  # Switch to RBAC-only (no access policy) for principle of least privilege; access via role assignments.
  rbac_authorization_enabled = true

  tags = var.tags
}

resource "azurerm_storage_account" "main" {
  count = var.enable_ai_foundry ? 1 : 0
  # Storage account names are globally unique and must be 3-24 lowercase alphanumeric.
  name                            = local.storage_account_name
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  allow_nested_items_to_be_public = false
  # Entra ID only auth: disable shared keys & default to OAuth
  shared_access_key_enabled       = false
  default_to_oauth_authentication = true
  queue_encryption_key_type       = "Account"
  table_encryption_key_type       = "Account"
  public_network_access_enabled   = true
  min_tls_version                 = "TLS1_2"
  is_hns_enabled                  = false
  tags                            = var.tags

  blob_properties {
    delete_retention_policy {
      days = 7
    }
    versioning_enabled = false
  }

  lifecycle {
    # Azure services can inject CORS entries; keep provisioning idempotent.
    ignore_changes = [blob_properties[0].cors_rule]
  }
}

resource "azurerm_storage_container" "search_documents" {
  count                 = local.search_ingestion_enabled ? 1 : 0
  name                  = var.search_documents_container_name
  storage_account_id    = azurerm_storage_account.main[0].id
  container_access_type = "private"
}
