locals {
  app_registration_name = var.app_registration_name != "" ? var.app_registration_name : "${var.project_name}-auth-${var.environment}"
  auth_client_id = var.enable_container_app_auth ? (var.create_app_registration ? azuread_application.container_app_auth[0].client_id : var.existing_app_registration_client_id) : null
  auth_allowed_audiences = length(var.container_app_auth_allowed_audiences) > 0 ? var.container_app_auth_allowed_audiences : (
    local.auth_client_id != null ? ["api://${local.auth_client_id}"] : []
  )
}
