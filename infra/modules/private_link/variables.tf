############################
# Private Link Module Variables
############################

variable "enable" {
  description = "Whether to enable creation of the private link resources"
  type        = bool
  default     = true
}

variable "name_prefix" {
  description = "Prefix used for naming created resources (e.g. project-service)"
  type        = string
}

variable "environment" {
  description = "Deployment environment suffix"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group in which to create resources"
  type        = string
}

variable "location" {
  description = "Azure location for private endpoints (should match target resources)"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID where private endpoints will be placed"
  type        = string
}

variable "vnet_id" {
  description = "Virtual network ID for DNS zone link"
  type        = string
}

variable "dns_zone_name" {
  description = "Private DNS zone name (e.g., privatelink.openai.azure.com)"
  type        = string
}

variable "create_dns_zone" {
  description = "Create the private DNS zone (true) or assume it exists (false). When false, provide existing_dns_zone_id"
  type        = bool
  default     = true
}

variable "existing_dns_zone_id" {
  description = "Existing DNS zone ID when create_dns_zone = false"
  type        = string
  default     = ""
  validation {
    condition     = !(var.create_dns_zone == false && var.existing_dns_zone_id == "")
    error_message = "existing_dns_zone_id must be provided when create_dns_zone is false"
  }
}

variable "zone_link_name" {
  description = "Optional explicit name for the DNS zone virtual network link"
  type        = string
  default     = ""
}

variable "targets" {
  description = <<EOT
List of target resources to create private endpoints for. Each object:
  id                - Resource ID of the Azure service instance
  name              - Short logical name used in naming (must be unique in list)
  subresource_names - List of subresource names (service-specific) for the private service connection
EOT
  type = list(object({
    id                = string
    name              = string
    subresource_names = list(string)
  }))
  default = []
  validation {
    condition     = length(var.targets) == length(distinct([for t in var.targets : t.name]))
    error_message = "Each target.name must be unique"
  }
}

variable "tags" {
  description = "Tags to apply to created resources"
  type        = map(string)
  default     = {}
}

variable "private_endpoint_naming_pattern" {
  description = "Optional format for private endpoint names; placeholders: name_prefix, target_name, environment. If null, a default format is used."
  type        = string
  default     = null
}

variable "private_service_connection_naming_pattern" {
  description = "Optional format for PSC names; placeholders: name_prefix, target_name, environment. If null, a default format is used."
  type        = string
  default     = null
}
