# Azure AI Search Terraform Configuration

This project now provisions Azure AI Search end-to-end with Terraform only:
- Search service (azurerm)
- Search index, data source, skillset, and indexer (AzAPI data plane)
- Managed identity RBAC for indexing and vectorization

## Overview

Implemented resources:
- `azurerm_search_service.main`
- `azapi_data_plane_resource.search_index`
- `azapi_data_plane_resource.search_data_source`
- `azapi_data_plane_resource.search_skillset`
- `azapi_data_plane_resource.search_indexer`

The ingestion flow is fully managed:
- Blob storage container as source
- Scheduled indexer (`PT5M` by default)
- Text chunking + Azure OpenAI embeddings
- Vector search-ready index schema
- Native blob soft-delete detection

## Key Terraform Inputs

| Variable | Default | Purpose |
|---|---|---|
| `enable_search_managed_ingestion` | `true` | Enable managed pipeline resources |
| `search_documents_container_name` | `documents` | Source blob container |
| `search_index_name` | `documents` | Target index name |
| `search_indexer_schedule_interval` | `PT5M` | Incremental sync cadence |
| `search_embedding_model_name` | `text-embedding-3-small` | Embedding deployment/model |
| `search_embedding_model_version` | `1` | Embedding model version |
| `search_embedding_dimensions` | `1536` | Vector field dimensions |

## RBAC

Search service managed identity gets:
- `Storage Blob Data Reader` on storage account
- `Cognitive Services OpenAI User` on Azure OpenAI account

Workload identity gets:
- `Search Service Contributor`
- `Search Index Data Contributor`

Optional local developer RBAC is controlled by:
- `local_dev_rbac` (bool)
- `local_developer_principal_object_id` (optional override)

## Outputs and Local Dev Flow

Terraform outputs expose Search pipeline names and endpoints for deployment and local use, including:
- `AZURE_SEARCH_ENDPOINT`
- `AZURE_SEARCH_SERVICE_ENDPOINT`
- `AZURE_SEARCH_SERVICE_NAME`
- `AZURE_SEARCH_INDEX`
- `search_data_source_name`
- `search_skillset_name`
- `search_indexer_name`

These are surfaced into `azd env get-values` after `azd provision` / `azd up`.
