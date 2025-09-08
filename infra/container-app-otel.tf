############################################
# Container App Environment - Managed OpenTelemetry -> App Insights
# Using AzAPI since azurerm_container_app_environment (v4.x) does not yet
# expose openTelemetryConfiguration / appInsightsConfiguration blocks.
#
# This enables:
#  - Logs  -> Application Insights
#  - Traces -> Application Insights
# Metrics to App Insights are not supported by the managed agent (as of docs).
#
# Requirements:
#  - Application code still needs OTEL SDK instrumentation.
#  - App Insights connection string is not secret; safe to embed.
############################################

resource "azapi_update_resource" "container_app_env_otel" {
  count = var.enable_container_apps_managed_otel ? 1 : 0

  type        = "Microsoft.App/managedEnvironments@2024-10-02-preview"
  resource_id = azurerm_container_app_environment.main.id

  # Ensure environment and App Insights exist first
  depends_on = [
    azurerm_container_app_environment.main,
    azurerm_application_insights.main
  ]

  body = jsonencode({
    properties = {
      # Preserve existing Log Analytics logs configuration (required by API validation)
      # Without including this, the 2024-10-02-preview endpoint returns:
      #   "LogAnalyticsConfiguration is invalid. Must provide a valid LogAnalyticsConfiguration"
      # because the patch appears to expect the existing appLogsConfiguration block when one
      # is already configured on the environment (it was originally set via the azurerm resource).
      appLogsConfiguration = {
        destination              = "log-analytics"
        logAnalyticsConfiguration = {
          customerId = azurerm_log_analytics_workspace.main.workspace_id
          sharedKey  = azurerm_log_analytics_workspace.main.primary_shared_key
        }
      }
      appInsightsConfiguration = {
        connectionString = azurerm_application_insights.main.connection_string
      }
      openTelemetryConfiguration = {
        tracesConfiguration = {
          destinations = ["appInsights"]
        }
        logsConfiguration = {
          destinations = ["appInsights"]
        }
      }
    }
  })
}
