#!/usr/bin/env bash
set -euo pipefail

image=$(azd env get-value SERVICE_API_IMAGE_NAME 2>/dev/null || true)
resource_exists=$(azd env get-value SERVICE_API_RESOURCE_EXISTS 2>/dev/null || true)

if [[ "$resource_exists" != "true" || -z "$image" ]]; then
  exit 0
fi

if [[ "$image" == mcr.microsoft.com/azuredocs/containerapps-helloworld:latest* ]]; then
  exit 0
fi

current=$(azd env get-value TF_VAR_container_image_revision 2>/dev/null || true)

if [[ "$image" == "$current" ]]; then
  exit 0
fi

azd env set CONTAINER_IMAGE_REVISION "$image"
azd env set TF_VAR_container_image_revision "$image"
