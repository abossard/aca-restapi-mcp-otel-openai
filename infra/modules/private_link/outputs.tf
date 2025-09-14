############################
# Private Link Module Outputs
############################

output "dns_zone_id" {
  value       = local.dns_zone_id
  description = "ID of the private DNS zone (created or existing)"
}

output "dns_zone_name" {
  value       = var.dns_zone_name
  description = "Name of the private DNS zone"
}

output "vnet_link_id" {
  value       = length(azurerm_private_dns_zone_virtual_network_link.this) > 0 ? azurerm_private_dns_zone_virtual_network_link.this[0].id : null
  description = "ID of the DNS zone virtual network link (null if disabled)"
}

output "private_endpoints" {
  description = "Map of private endpoint details keyed by target logical name"
  value = var.enable ? {
    for k, pe in azurerm_private_endpoint.this : k => {
      id           = pe.id
      name         = pe.name
      ip_addresses = [for c in pe.private_service_connection : c.private_ip_address]
      subresources = pe.private_service_connection[0].subresource_names
      target_id    = local.targets_map[k].id
    }
  } : {}
}

output "private_endpoint_ips" {
  description = "Map of first private IP for each endpoint"
  value       = var.enable ? { for k, v in azurerm_private_endpoint.this : k => v.private_service_connection[0].private_ip_address } : {}
}

output "created" {
  description = "True if module created resources (enable==true)"
  value       = var.enable
}
