# Container Apps Authentication Usage Guide

This document explains how to deploy and configure Azure Container Apps with authentication using our flexible Terraform configuration.

## Overview

Our Terraform configuration now provisions Container Apps Authentication natively (via AzAPI) — no post-deployment script required. Two modes are still supported:

1. **Automatic App Registration with Federated (Workload) Identity** (Recommended, secretless)
2. **Existing App Registration with Client Secret** (Only if you must reuse an existing registration)

## Deployment Options

### Option 1: Automatic App Registration with Federated Trust (Recommended)

This option creates a new app registration with federated identity credentials, eliminating the need for client secrets.

#### 1. Deploy Infrastructure

```bash
cd infra

# Create terraform.tfvars
cat > terraform.tfvars << EOF
# Basic Configuration
project_name = "my-api-project"
environment  = "dev"
location     = "Switzerland North"

# Authentication Configuration
enable_container_app_auth = true
create_app_registration  = true
app_registration_name    = "my-api-auth-app"  # Optional, defaults to project-auth-environment

# Optional: Enable private endpoints
enable_private_endpoints = false
EOF

# Deploy
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

Terraform applies the authentication config automatically as part of the same apply (resource: Microsoft.App/containerApps/authConfigs name "current"). No extra step needed.

### Option 2: Existing App Registration with Client Secret

This option uses an existing app registration that you've created manually.

#### 1. Prerequisites

First, create an app registration manually in Azure Portal or via Azure CLI:

```bash
# Create app registration
APP_REGISTRATION=$(az ad app create \
  --display-name "my-api-auth-app" \
  --web-redirect-uris "https://my-api-project-ca-dev.azurecontainerapps.io/.auth/login/aad/callback" \
  --enable-id-token-issuance)

CLIENT_ID=$(echo $APP_REGISTRATION | jq -r .appId)

# Create client secret
CLIENT_SECRET=$(az ad app credential reset \
  --id $CLIENT_ID \
  --append \
  --query password --output tsv)

echo "Client ID: $CLIENT_ID"
echo "Client Secret: $CLIENT_SECRET"
```

#### 2. Deploy Infrastructure

```bash
cd infra

# Create terraform.tfvars
cat > terraform.tfvars << EOF
# Basic Configuration
project_name = "my-api-project"
environment  = "dev"
location     = "Switzerland North"

# Authentication Configuration
enable_container_app_auth              = true
create_app_registration                = false
existing_app_registration_client_id    = "12345678-1234-1234-1234-123456789abc"
existing_app_registration_client_secret = "your-client-secret-here"
EOF

# Deploy
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

Authentication is provisioned during the same Terraform apply. Provide the secret via `existing_app_registration_client_secret` and it is passed into the Container App secret/env + authConfig.

## Variable Reference

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `enable_container_app_auth` | bool | `true` | Enable authentication for Container Apps |
| `create_app_registration` | bool | `true` | Create new app registration (true) or use existing (false) |
| `app_registration_name` | string | `""` | Name for new app registration (auto-generated if empty) |
| `existing_app_registration_client_id` | string | `""` | Client ID of existing app registration (when reusing) |
| `existing_app_registration_client_secret` | string | `""` | Client secret for existing app registration (optional if federated) |
| `container_app_auth_require_authentication` | bool | `true` | Force redirect to provider if true |
| `container_app_auth_unauthenticated_action` | string | `RedirectToLoginPage` | Behavior for unauthenticated requests |
| `container_app_auth_allowed_audiences` | list(string) | `[]` | If empty defaults to `api://<client_id>` |

## Authentication Flow

### For Users
1. User accesses the Container App URL
2. Container Apps authentication middleware redirects to Azure AD
3. User authenticates with Azure AD
4. Azure AD redirects back to Container App with authentication token
5. User can access the protected application

### For Applications
When authentication is enabled, your application can access user information through headers:

```python
from fastapi import FastAPI, Request

app = FastAPI()

@app.get("/user")
async def get_user_info(request: Request):
    # Container Apps authentication headers
    user_principal = request.headers.get("x-ms-client-principal-name")
    user_id = request.headers.get("x-ms-client-principal-id")
    
    return {
        "user": user_principal,
        "user_id": user_id,
        "authenticated": user_principal is not None
    }
```

## Terraform Outputs

After deployment, you'll get several useful outputs:

```bash
# Check authentication status
terraform output authentication_enabled

# Get app registration details
terraform output app_registration_client_id
terraform output app_registration_object_id

# Auth config managed entirely by Terraform (no script output anymore)
```

## Example Complete Deployment

Here's a complete example from start to finish:

```bash
# 1. Clone and setup
git clone <repository-url>
cd aca-restapi-mcp-otel-openai/infra

# 2. Create configuration
cat > terraform.tfvars << EOF
project_name = "demo-api"
environment  = "dev"
location     = "Switzerland North"

enable_container_app_auth = true
create_app_registration  = true
app_registration_name    = "demo-api-auth"

enable_ai_foundry = true
enable_private_endpoints = false
EOF

# 3. Deploy infrastructure
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# 4. Access your application
CONTAINER_APP_URL=$(terraform output -raw container_app_url)
echo "Your application is available at: $CONTAINER_APP_URL"
```

## Troubleshooting

### Common Issues

1. **Redirect URI mismatch**
   - Terraform builds the redirect as: `https://<fqdn>/.auth/login/aad/callback`
   - If reusing an existing app registration ensure this redirect is present in the AAD app.

2. **401 after login**
   - Confirm allowed audiences (`container_app_auth_allowed_audiences`) includes the token audience.
   - If left empty Terraform sets `api://<client_id>`; ensure your client uses that audience.

3. **Secret-based auth failing**
   - Ensure `existing_app_registration_client_secret` populated and not expired.
   - Confirm env var `MICROSOFT_PROVIDER_AUTHENTICATION_SECRET` present in Container App revision.

4. **Federated identity not issuing tokens**
   - Check federated credential subject matches expected format (see Terraform resource).
   - Propagation can take a few minutes after creation.

### Verification

Test authentication by accessing your Container App:

```bash
# Get the Container App URL
CONTAINER_APP_URL=$(terraform output -raw container_app_url)

# Test unauthenticated access (should redirect to login)
curl -I $CONTAINER_APP_URL

# Test authenticated access via browser
open $CONTAINER_APP_URL
```

## Security Considerations

1. Prefer federated identity (no long-lived secret surface).
2. Rotate client secrets promptly if you must use them (short expiry recommended).
3. Limit audiences to only those required by your clients.
4. Consider enabling conditional access policies in Entra ID for stronger posture.

## Cost Implications

- Authentication adds no additional Azure costs
- App registrations are free
- Container Apps billing is unchanged

This authentication setup provides enterprise-grade security with minimal operational overhead.