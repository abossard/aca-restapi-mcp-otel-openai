# Private Link Module

Reusable module to provision:
- Private DNS zone (optional)
- DNS zone virtual network link
- One private endpoint per target resource (all of the same service category)

## Inputs
- enable (bool)
- name_prefix (string)
- environment (string)
- resource_group_name (string)
- location (string)
- subnet_id (string)
- vnet_id (string)
- dns_zone_name (string)
- create_dns_zone (bool)
- existing_dns_zone_id (string)
- zone_link_name (string)
- targets (list(object)) with: id, name, subresource_names
- tags (map(string))
- private_endpoint_naming_pattern (string)
- private_service_connection_naming_pattern (string)

## Outputs
- dns_zone_id
- dns_zone_name
- vnet_link_id
- private_endpoints (map)
- private_endpoint_ips (map)
- created (bool)

## Notes
- Call once per service type/domain (e.g., OpenAI, search, acr, etc.).
- All targets share same DNS zone & subnet.
- `create_dns_zone=false` allows reuse (supply `existing_dns_zone_id`).
- Target names must be unique; used as map keys.
