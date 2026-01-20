#!/usr/bin/env bash
set -euo pipefail

azd_env_name=$(azd env get-value AZURE_ENV_NAME 2>/dev/null || true)
tf_env=$(azd env get-value TF_VAR_environment 2>/dev/null || true)
tf_azure_env=$(azd env get-value TF_VAR_azure_env_name 2>/dev/null || true)
project_name=$(azd env get-value TF_VAR_project_name 2>/dev/null || true)

# Derive a sane default project name if not set
if [[ -z "$project_name" ]]; then
  project_name="aca-restapi-mcp"
fi

# If AZURE_ENV_NAME is empty, fall back to TF_VAR_environment, otherwise default to "dev"
if [[ -z "$azd_env_name" ]]; then
  if [[ -n "$tf_env" ]]; then
    azd_env_name="$tf_env"
  else
    azd_env_name="dev"
  fi
  azd env set AZURE_ENV_NAME "$azd_env_name"
fi

# Ensure TF_VAR_environment and TF_VAR_azure_env_name match the resolved azd env name
if [[ "$tf_env" != "$azd_env_name" ]]; then
  azd env set TF_VAR_environment "$azd_env_name"
fi
if [[ "$tf_azure_env" != "$azd_env_name" ]]; then
  azd env set TF_VAR_azure_env_name "$azd_env_name"
fi

# Ensure TF_VAR_resource_group_name is set so azd can find the RG without manual vars
tf_rg=$(azd env get-value TF_VAR_resource_group_name 2>/dev/null || true)
if [[ -z "$tf_rg" ]]; then
  derived_rg="rg-${project_name}-${azd_env_name}"
  azd env set TF_VAR_resource_group_name "$derived_rg"
fi
