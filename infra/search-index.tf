# Managed Azure AI Search ingestion pipeline (Option 1)
# Uses AzAPI data-plane resources to keep ingestion fully Terraform-managed.

resource "azapi_data_plane_resource" "search_index" {
  count     = local.search_ingestion_enabled ? 1 : 0
  type      = "Microsoft.Search/searchServices/indexes@2024-07-01"
  parent_id = local.search_data_plane_parent_id
  name      = var.search_index_name
  body = {
    fields = [
      {
        name       = "chunk_id"
        type       = "Edm.String"
        key        = true
        filterable = true
        analyzer   = "keyword"
      },
      {
        name       = "parent_id"
        type       = "Edm.String"
        filterable = true
      },
      {
        name        = "title"
        type        = "Edm.String"
        searchable  = true
        retrievable = true
        filterable  = true
        sortable    = true
      },
      {
        name        = "content"
        type        = "Edm.String"
        searchable  = true
        retrievable = true
      },
      {
        name        = "source"
        type        = "Edm.String"
        searchable  = false
        retrievable = true
        filterable  = true
      },
      {
        name                = "content_vector"
        type                = "Collection(Edm.Single)"
        searchable          = true
        retrievable         = false
        stored              = false
        dimensions          = var.search_embedding_dimensions
        vectorSearchProfile = local.search_vector_profile_name
      }
    ]
    vectorSearch = {
      algorithms = [
        {
          name = local.search_vector_algorithm_name
          kind = "hnsw"
          hnswParameters = {
            m              = 4
            efConstruction = 400
            efSearch       = 100
            metric         = "cosine"
          }
        }
      ]
      profiles = [
        {
          name       = local.search_vector_profile_name
          algorithm  = local.search_vector_algorithm_name
          vectorizer = local.search_vectorizer_name
        }
      ]
      vectorizers = [
        {
          name = local.search_vectorizer_name
          kind = "azureOpenAI"
          azureOpenAIParameters = {
            resourceUri  = trimsuffix(azurerm_cognitive_account.ai_services[0].endpoint, "/")
            deploymentId = azurerm_cognitive_deployment.embedding[0].name
            modelName    = var.search_embedding_model_name
          }
        }
      ]
    }
  }

  depends_on = [
    azurerm_role_assignment.search_index_data_contributor
  ]
}

resource "azapi_data_plane_resource" "search_data_source" {
  count     = local.search_ingestion_enabled ? 1 : 0
  type      = "Microsoft.Search/searchServices/datasources@2024-07-01"
  parent_id = local.search_data_plane_parent_id
  name      = local.search_data_source_name
  body = {
    type = "azureblob"
    credentials = {
      connectionString = "ResourceId=${azurerm_storage_account.main[0].id};"
    }
    container = {
      name = azurerm_storage_container.search_documents[0].name
    }
    dataDeletionDetectionPolicy = {
      "@odata.type" = "#Microsoft.Azure.Search.NativeBlobSoftDeleteDeletionDetectionPolicy"
    }
  }

  depends_on = [
    azurerm_role_assignment.search_service_storage_blob_reader
  ]
}

resource "azapi_data_plane_resource" "search_skillset" {
  count     = local.search_ingestion_enabled ? 1 : 0
  type      = "Microsoft.Search/searchServices/skillsets@2024-07-01"
  parent_id = local.search_data_plane_parent_id
  name      = local.search_skillset_name
  body = {
    skills = [
      {
        "@odata.type"       = "#Microsoft.Skills.Text.SplitSkill"
        name                = "split-skill"
        description         = "Split content into overlapping chunks."
        textSplitMode       = "pages"
        maximumPageLength   = 2000
        pageOverlapLength   = 500
        maximumPagesToTake  = 0
        defaultLanguageCode = "en"
        inputs = [
          {
            name   = "text"
            source = "/document/content"
          }
        ]
        outputs = [
          {
            name       = "textItems"
            targetName = "pages"
          }
        ]
      },
      {
        "@odata.type" = "#Microsoft.Skills.Text.AzureOpenAIEmbeddingSkill"
        name          = "embedding-skill"
        description   = "Create embeddings for each chunk."
        context       = "/document/pages/*"
        resourceUri   = trimsuffix(azurerm_cognitive_account.ai_services[0].endpoint, "/")
        deploymentId  = azurerm_cognitive_deployment.embedding[0].name
        modelName     = var.search_embedding_model_name
        dimensions    = var.search_embedding_dimensions
        inputs = [
          {
            name   = "text"
            source = "/document/pages/*"
          }
        ]
        outputs = [
          {
            name       = "embedding"
            targetName = "chunk_vector"
          }
        ]
      }
    ]
    indexProjections = {
      selectors = [
        {
          targetIndexName    = var.search_index_name
          parentKeyFieldName = "parent_id"
          sourceContext      = "/document/pages/*"
          mappings = [
            {
              name   = "content"
              source = "/document/pages/*"
            },
            {
              name   = "content_vector"
              source = "/document/pages/*/chunk_vector"
            },
            {
              name   = "title"
              source = "/document/metadata_storage_name"
            },
            {
              name   = "source"
              source = "/document/metadata_storage_path"
            }
          ]
        }
      ]
      parameters = {
        projectionMode = "skipIndexingParentDocuments"
      }
    }
  }

  depends_on = [
    azapi_data_plane_resource.search_index,
    azurerm_role_assignment.search_service_openai_user
  ]
}

resource "azapi_data_plane_resource" "search_indexer" {
  count     = local.search_ingestion_enabled ? 1 : 0
  type      = "Microsoft.Search/searchServices/indexers@2024-07-01"
  parent_id = local.search_data_plane_parent_id
  name      = local.search_indexer_name
  body = {
    dataSourceName  = azapi_data_plane_resource.search_data_source[0].name
    targetIndexName = azapi_data_plane_resource.search_index[0].name
    skillsetName    = azapi_data_plane_resource.search_skillset[0].name
    schedule = {
      interval = var.search_indexer_schedule_interval
    }
    parameters = {
      configuration = {
        dataToExtract                                 = "contentAndMetadata"
        parsingMode                                   = "default"
        failOnUnsupportedContentType                  = false
        failOnUnprocessableDocument                   = false
        indexStorageMetadataOnlyForOversizedDocuments = true
      }
      maxFailedItems         = -1
      maxFailedItemsPerBatch = -1
    }
  }

  depends_on = [
    azapi_data_plane_resource.search_skillset
  ]
}
