############################
# Core Variables
############################
variable "location" {
  description = "Azure region for resource deployment"
  type        = string
  default     = "Switzerland North"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-aca-restapi-mcp-otel"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "aca-restapi-mcp"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "tags" {
  description = "Resource tags for organization and cost tracking"
  type        = map(string)
  default = {
    Environment = "dev"
    Project     = "aca-restapi-mcp-otel-openai"
    Purpose     = "AI-Enhanced REST API"
  }
}

############################
# Feature Toggles
############################
variable "enable_private_endpoints" {
  description = "Enable private endpoints for Azure services"
  type        = bool
  default     = false
}

variable "enable_ai_foundry" {
  description = "Enable Azure AI Foundry workspace instead of standalone OpenAI"
  type        = bool
  default     = true
}

variable "enable_container_app_auth" {
  description = "Enable authentication for Container Apps"
  type        = bool
  default     = true
}

variable "container_app_port" {
  description = "Container listening port exposed via ingress"
  type        = number
  default     = 80
}

variable "container_app_public" {
  description = "Expose the Container App publicly via external ingress. If false, ingress is internal-only."
  type        = bool
  default     = true
}

variable "enable_container_apps_managed_otel" {
  description = "Enable Managed OpenTelemetry agent in the Container App Environment exporting traces and logs to Application Insights"
  type        = bool
  default     = true
}


variable "container_app_auth_require_authentication" {
  description = "Whether to require authentication globally (Redirect unauthenticated users)."
  type        = bool
  default     = true
}

variable "container_app_auth_unauthenticated_action" {
  description = "Action for unauthenticated requests: RedirectToLoginPage or AllowAnonymous."
  type        = string
  default     = "RedirectToLoginPage"
  validation {
    condition     = contains(["RedirectToLoginPage", "AllowAnonymous"], var.container_app_auth_unauthenticated_action)
    error_message = "container_app_auth_unauthenticated_action must be one of RedirectToLoginPage or AllowAnonymous"
  }
}

variable "container_app_auth_allowed_audiences" {
  description = "List of allowed audiences for AAD tokens (defaults to api://<client_id>)."
  type        = list(string)
  default     = []
}

############################
# Networking
############################
variable "vnet_address_space" {
  description = "Virtual network address space"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "private_endpoint_subnet_address_prefixes" {
  description = "Address prefixes for private endpoint subnet"
  type        = list(string)
  default     = ["10.0.1.0/24"]
}

############################
# Authentication / AAD
############################
variable "create_app_registration" {
  description = "Create a new app registration with federated trust (true) or use existing app registration with secret (false)"
  type        = bool
  default     = true
}

variable "existing_app_registration_client_id" {
  description = "Client ID of existing app registration (only used when create_app_registration = false)"
  type        = string
  default     = ""
  sensitive   = false
}

variable "existing_app_registration_client_secret" {
  description = "Client secret of existing app registration (only used when create_app_registration = false)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "app_registration_name" {
  description = "Name for the app registration (only used when create_app_registration = true)"
  type        = string
  default     = ""
}

############################
# Local Dev RBAC
############################
variable "local_dev_rbac" {
  description = "Grant current signed-in user broad read/usage roles for local dev convenience"
  type        = bool
  default     = false
}
