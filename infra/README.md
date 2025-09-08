# Infrastructure Layout

This directory was refactored from a single `main.tf` into multiple concern-focused files.

## File Map
- `versions.tf` – Terraform + providers.
- `variables.tf` – Input variables (grouped by category).
- `locals.tf` – Derived names/placeholders.
- `resource-group.tf` – Resource group anchor.
- `monitoring.tf` – Log Analytics + Application Insights.
- `identity.tf` – User-assigned identity + client config + random suffix.
- `registry.tf` – Azure Container Registry.
- `network.tf` – VNet + Subnet (conditional on private endpoints).
- `private-dns.tf` – Private DNS zones + links.
- `private-endpoints.tf` – All private endpoints.
- `keyvault-storage.tf` – Key Vault + Storage (AI Foundry dependencies).
- `ai-foundry.tf` – AI Foundry hub + project.
- `ai-services.tf` – Cognitive account + model deployments.
- `search.tf` – Azure AI Search service.
- `rbac.tf` – Role assignments (grouped by service).
- `aad-auth.tf` – App Registration + SP + federated identity + auth role assignments.
- `container-app-environment.tf` – Container App Environment.
- `container-app.tf` – Container App definition.
- `outputs.tf` – Consolidated outputs.

## Notes
- Large explicit `depends_on` removed from container app; rely on implicit graph. Reintroduce if RBAC propagation races appear.
- Conditional resources guarded by feature flags: `enable_ai_foundry`, `enable_private_endpoints`, `enable_container_app_auth`.
- Authentication configuration for Container Apps still requires post-deployment script (see output `post_deployment_auth_command`).

## Next Improvements (Optional)
- Add remote backend (`backend.tf`).
- Introduce `tflint` / `terraform validate` in CI.
- Use Key Vault secrets for sensitive env values when added.
- Consider module extraction only if reuse across stacks emerges.
