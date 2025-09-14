# Baseline public scenario: no private endpoints, external ingress
# Adjust values as needed for your subscription / region.

location                          = "Sweden Central"
project_name                      = "aca-restapi"
resource_group_name               = "rg-aca-restapi"
environment                       = "dev"

# Required selections (added):
container_registry_sku            = "Basic"          # or Standard | Premium
ai_model_set                      = "minimal"        # or full

# Feature toggles
enable_private_endpoints          = false
enable_ai_foundry                 = true
enable_container_app_auth         = true
local_dev_rbac                    = true

# Authentication (Entra ID) - using new app registration + federated (workload) identity
# Set create_app_registration=false and provide existing IDs/secrets if reusing an app.
create_app_registration           = true
app_registration_name             = "" # leave blank -> derived: <project>-auth-<env>

# Auth behavior controls (added via Terraform azapi authConfig)
container_app_auth_require_authentication   = true
container_app_auth_unauthenticated_action   = "RedirectToLoginPage" # or AllowAnonymous
# Leave audiences empty -> defaults to api://<client_id>
container_app_auth_allowed_audiences        = []

# Networking (kept default; only used if private endpoints later switched on)
vnet_address_space                = ["10.0.0.0/16"]
private_endpoint_subnet_address_prefixes = ["10.0.1.0/24"]

# Tags override if desired
# tags = { Environment = "dev" Project = "aca-restapi-mcp-otel-openai" Purpose = "AI-Enhanced REST API" }
