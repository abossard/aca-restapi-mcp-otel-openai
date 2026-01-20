# Container Registry
resource "azurerm_container_registry" "main" {
  name                = "${replace(var.project_name, "-", "")}acr${var.environment_name}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = var.container_registry_sku
  admin_enabled       = false # disable admin (username/password) access; use managed identity / AAD tokens
  # Only disable public network access when both private endpoints enabled AND Premium sku (requirement)
  # Always keep public network access enabled so local tooling (azd deploy) can reach the registry without private networking.
  public_network_access_enabled = true
  # Include azd-service-name to optionally help azd associate build output (not required, but consistent)
  tags = merge(var.tags, {
    "azd-env-name" = var.environment_name
  })
}

# Allow the workload user-assigned identity to pull from ACR (AcrPull role)
resource "azurerm_role_assignment" "workload_identity_acr_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.main.principal_id
}
