############################
# Private Link Module Main
############################

locals {
  zone_link_name_effective = var.zone_link_name != "" ? var.zone_link_name : "${var.name_prefix}-dns-link-${var.environment}"
  dns_zone_id              = var.enable ? (var.create_dns_zone ? (length(azurerm_private_dns_zone.this) > 0 ? azurerm_private_dns_zone.this[0].id : null) : var.existing_dns_zone_id) : null
  targets_map              = { for t in var.targets : t.name => t }
}

# Optional DNS Zone
resource "azurerm_private_dns_zone" "this" {
  count               = var.enable && var.create_dns_zone ? 1 : 0
  name                = var.dns_zone_name
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# VNet Link (only if enabled and we have a zone id)
resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  count                 = var.enable ? 1 : 0
  name                  = local.zone_link_name_effective
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = var.dns_zone_name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
  tags                  = var.tags
  depends_on            = [azurerm_private_dns_zone.this]
}

# Private Endpoints for each target
resource "azurerm_private_endpoint" "this" {
  for_each            = var.enable ? local.targets_map : {}
  name                = coalesce(var.private_endpoint_naming_pattern, format("%s-%s-pe-%s", var.name_prefix, each.key, var.environment))
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = coalesce(var.private_service_connection_naming_pattern, format("%s-%s-psc-%s", var.name_prefix, each.key, var.environment))
    private_connection_resource_id = each.value.id
    subresource_names              = each.value.subresource_names
    is_manual_connection           = false
  }

  dynamic "private_dns_zone_group" {
    for_each = local.dns_zone_id == null ? [] : [1]
    content {
      name                 = "default"
      private_dns_zone_ids = [local.dns_zone_id]
    }
  }

  lifecycle {
    ignore_changes = [private_dns_zone_group] # allows external zone adjustments
  }

  depends_on = [azurerm_private_dns_zone_virtual_network_link.this]
}
