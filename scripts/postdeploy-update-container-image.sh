#!/usr/bin/env bash
set -euo pipefail

rg=$(azd env get-value resource_group_name 2>/dev/null || true)
app_id=$(azd env get-value container_app_id 2>/dev/null || true)

if [[ -z "$rg" || -z "$app_id" ]]; then
  exit 0
fi

app_name=${app_id##*/}
image=$(az containerapp revision list \
  --resource-group "$rg" \
  --name "$app_name" \
  --query "[?properties.active].properties.template.containers[0].image" \
  -o tsv | head -n1)

if [[ -z "$image" ]]; then
  exit 0
fi

current=$(azd env get-value TF_VAR_container_image_revision 2>/dev/null || true)

if [[ "$image" == "$current" ]]; then
  exit 0
fi

azd env set CONTAINER_IMAGE_REVISION "$image"
azd env set TF_VAR_container_image_revision "$image"
azd provision --only infra --no-prompt
