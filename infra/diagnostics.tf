############################################
# Azure Monitor Diagnostic Settings
# Route core platform resource logs/metrics into the shared Log Analytics workspace.
############################################

locals {
  aoai_diagnostic_log_categories = concat(
    ["Audit", "AzureOpenAIRequestUsage", "Trace"],
    var.enable_aoai_request_response_logs ? ["RequestResponse"] : []
  )
}

data "azurerm_monitor_diagnostic_categories" "search_service" {
  count       = var.enable_resource_diagnostics ? 1 : 0
  resource_id = azurerm_search_service.main.id
}

resource "azurerm_monitor_diagnostic_setting" "search_service" {
  count                          = var.enable_resource_diagnostics ? 1 : 0
  name                           = "${local.env_token}-srchdiag"
  target_resource_id             = azurerm_search_service.main.id
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.main.id
  log_analytics_destination_type = "Dedicated"

  dynamic "enabled_log" {
    for_each = toset([
      for c in data.azurerm_monitor_diagnostic_categories.search_service[0].log_category_types : c if c == "OperationLogs"
    ])
    content {
      category = enabled_log.value
    }
  }

  dynamic "enabled_metric" {
    for_each = toset(data.azurerm_monitor_diagnostic_categories.search_service[0].metrics)
    content {
      category = enabled_metric.value
    }
  }
}

data "azurerm_monitor_diagnostic_categories" "ai_services" {
  count       = var.enable_resource_diagnostics && var.enable_ai_foundry ? 1 : 0
  resource_id = azurerm_cognitive_account.ai_services[0].id
}

resource "azurerm_monitor_diagnostic_setting" "ai_services" {
  count                          = var.enable_resource_diagnostics && var.enable_ai_foundry ? 1 : 0
  name                           = "${local.env_token}-aoaidiag"
  target_resource_id             = azurerm_cognitive_account.ai_services[0].id
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.main.id
  log_analytics_destination_type = "Dedicated"

  dynamic "enabled_log" {
    for_each = toset([
      for c in data.azurerm_monitor_diagnostic_categories.ai_services[0].log_category_types : c if contains(local.aoai_diagnostic_log_categories, c)
    ])
    content {
      category = enabled_log.value
    }
  }

  dynamic "enabled_metric" {
    for_each = toset(data.azurerm_monitor_diagnostic_categories.ai_services[0].metrics)
    content {
      category = enabled_metric.value
    }
  }
}

data "azurerm_monitor_diagnostic_categories" "key_vault" {
  count       = var.enable_resource_diagnostics && var.enable_ai_foundry ? 1 : 0
  resource_id = azurerm_key_vault.main[0].id
}

resource "azurerm_monitor_diagnostic_setting" "key_vault" {
  count                          = var.enable_resource_diagnostics && var.enable_ai_foundry ? 1 : 0
  name                           = "${local.env_token}-kvdiag"
  target_resource_id             = azurerm_key_vault.main[0].id
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.main.id
  log_analytics_destination_type = "Dedicated"

  dynamic "enabled_log" {
    for_each = toset([
      for c in data.azurerm_monitor_diagnostic_categories.key_vault[0].log_category_types : c if contains(["AuditEvent", "AzurePolicyEvaluationDetails"], c)
    ])
    content {
      category = enabled_log.value
    }
  }

  dynamic "enabled_metric" {
    for_each = toset(data.azurerm_monitor_diagnostic_categories.key_vault[0].metrics)
    content {
      category = enabled_metric.value
    }
  }
}

data "azurerm_monitor_diagnostic_categories" "storage_account" {
  count       = var.enable_resource_diagnostics && var.enable_ai_foundry ? 1 : 0
  resource_id = azurerm_storage_account.main[0].id
}

resource "azurerm_monitor_diagnostic_setting" "storage_account" {
  count                          = var.enable_resource_diagnostics && var.enable_ai_foundry ? 1 : 0
  name                           = "${local.env_token}-sadiag"
  target_resource_id             = azurerm_storage_account.main[0].id
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.main.id
  log_analytics_destination_type = "Dedicated"

  dynamic "enabled_log" {
    for_each = toset(data.azurerm_monitor_diagnostic_categories.storage_account[0].log_category_types)
    content {
      category = enabled_log.value
    }
  }

  dynamic "enabled_metric" {
    for_each = toset(data.azurerm_monitor_diagnostic_categories.storage_account[0].metrics)
    content {
      category = enabled_metric.value
    }
  }
}

data "azurerm_monitor_diagnostic_categories" "storage_blob_service" {
  count       = var.enable_resource_diagnostics && var.enable_ai_foundry ? 1 : 0
  resource_id = "${azurerm_storage_account.main[0].id}/blobServices/default"
}

resource "azurerm_monitor_diagnostic_setting" "storage_blob_service" {
  count                          = var.enable_resource_diagnostics && var.enable_ai_foundry ? 1 : 0
  name                           = "${local.env_token}-blobdiag"
  target_resource_id             = "${azurerm_storage_account.main[0].id}/blobServices/default"
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.main.id
  log_analytics_destination_type = "Dedicated"

  dynamic "enabled_log" {
    for_each = toset([
      for c in data.azurerm_monitor_diagnostic_categories.storage_blob_service[0].log_category_types : c if contains(["StorageRead", "StorageWrite", "StorageDelete"], c)
    ])
    content {
      category = enabled_log.value
    }
  }

  dynamic "enabled_metric" {
    for_each = toset(data.azurerm_monitor_diagnostic_categories.storage_blob_service[0].metrics)
    content {
      category = enabled_metric.value
    }
  }
}

data "azurerm_monitor_diagnostic_categories" "container_registry" {
  count       = var.enable_resource_diagnostics ? 1 : 0
  resource_id = azurerm_container_registry.main.id
}

resource "azurerm_monitor_diagnostic_setting" "container_registry" {
  count                          = var.enable_resource_diagnostics ? 1 : 0
  name                           = "${local.env_token}-acrdiag"
  target_resource_id             = azurerm_container_registry.main.id
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.main.id
  log_analytics_destination_type = "Dedicated"

  dynamic "enabled_log" {
    for_each = toset(data.azurerm_monitor_diagnostic_categories.container_registry[0].log_category_types)
    content {
      category = enabled_log.value
    }
  }

  dynamic "enabled_metric" {
    for_each = toset(data.azurerm_monitor_diagnostic_categories.container_registry[0].metrics)
    content {
      category = enabled_metric.value
    }
  }
}
