# Container Apps Authentication Usage Guide

This guide explains how to deploy and use Azure Container Apps authentication in this project.

## Overview

Two authentication modes are supported:

1. **Federated Identity** (Recommended) - Secretless, auto-created app registration
2. **Existing App Registration** - Use your own app registration with client secret

## Quick Start

### Deploy with Federated Identity (Default)

```bash
# Initialize environment
azd init -e myenv

# Deploy (creates app registration automatically)
azd up
```

That's it! Authentication is configured automatically.

### Deploy with Existing App Registration

```bash
# Set your app registration details
azd env set TF_VAR_create_app_registration false
azd env set TF_VAR_existing_app_registration_client_id "your-client-id"
azd env set TF_VAR_existing_app_registration_client_secret "your-secret"

# Deploy
azd up
```

## Configuration Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `enable_container_app_auth` | bool | `true` | Enable authentication |
| `create_app_registration` | bool | `true` | Create new federated app reg |
| `app_registration_name` | string | auto | Custom name for app reg |
| `container_app_auth_require_authentication` | bool | `true` | Redirect unauthenticated users |
| `container_app_auth_unauthenticated_action` | string | `RedirectToLoginPage` | Action for unauth requests |

## How It Works

### User Authentication Flow

```
User → Container App → Entra ID Login → Redirect Back → Authenticated Access
```

1. User accesses the app URL
2. Container Apps middleware intercepts unauthenticated requests
3. User is redirected to Entra ID login
4. After login, user is redirected back with auth token
5. User can access the application

### Accessing User Identity in Code

```python
from fastapi import Request

@app.get("/me")
async def get_current_user(request: Request):
    return {
        "name": request.headers.get("x-ms-client-principal-name"),
        "id": request.headers.get("x-ms-client-principal-id"),
        "authenticated": request.headers.get("x-ms-client-principal-name") is not None
    }
```

Available headers:
- `x-ms-client-principal-name`: User's display name
- `x-ms-client-principal-id`: User's object ID
- `x-ms-client-principal`: Base64-encoded claims

## Testing Authentication

```bash
# Get the Container App URL
APP_URL=$(azd env get-values | grep CONTAINER_APP_URL | cut -d'=' -f2)

# Test unauthenticated (should redirect)
curl -I "$APP_URL"
# Expected: 302 redirect to login

# Open in browser to complete auth flow
open "$APP_URL"
```

## Allow Anonymous Access

To allow both authenticated and anonymous users:

```hcl
container_app_auth_require_authentication  = false
container_app_auth_unauthenticated_action = "AllowAnonymous"
```

Then check authentication in code:

```python
@app.get("/data")
async def get_data(request: Request):
    user = request.headers.get("x-ms-client-principal-name")
    if user:
        return {"data": "private data", "user": user}
    else:
        return {"data": "public data"}
```

## Troubleshooting

| Symptom | Cause | Solution |
|---------|-------|----------|
| Redirect URI mismatch | App reg URI doesn't match Container App | Check/update app registration |
| 401 after login | Audience mismatch | Verify `container_app_auth_allowed_audiences` |
| Login loop | Token validation failing | Check issuer URL and client ID |
| No user headers | Auth not enabled | Verify `enable_container_app_auth = true` |

## Outputs

After deployment:

```bash
# Check authentication status
terraform output authentication_enabled

# Get app registration client ID
terraform output app_registration_client_id
```

## Security Notes

- **Federated identity** eliminates secret management
- **HTTPS only**: Container Apps enforces HTTPS
- **Token validation**: Built-in validation of Entra ID tokens
- **No code changes**: Auth is handled by the platform

## Cost

- App registrations: Free
- Container Apps auth: No additional cost
- Standard Container Apps billing applies
