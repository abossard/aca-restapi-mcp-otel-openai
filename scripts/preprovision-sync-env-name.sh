#!/usr/bin/env bash
set -euo pipefail

azd_env_name=$(azd env get-value AZURE_ENV_NAME 2>/dev/null || true)
if [[ -z "$azd_env_name" ]]; then
  exit 0
fi

current=$(azd env get-value TF_VAR_environment 2>/dev/null || true)
if [[ "$current" == "$azd_env_name" ]]; then
  exit 0
fi

azd env set TF_VAR_environment "$azd_env_name"
