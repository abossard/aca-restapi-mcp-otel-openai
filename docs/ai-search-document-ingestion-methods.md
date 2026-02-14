# Azure AI Search Document Ingestion Methods

This document summarizes the main ways to ingest documents into Azure AI Search.

## Quick Comparison

| Method | Best for | Managed level | Change/Delete handling |
|---|---|---|---|
| Indexer pull model | Blob/ADLS/SQL/Cosmos/OneLake/SharePoint sources | High | Built-in change tracking; delete detection policy required |
| Indexer + integrated vectorization | RAG/search with chunking + embeddings | High | Same as indexer pull model |
| Push API (`docs/index`) | Custom app pipelines or non-indexer sources | Medium | You own upsert/delete logic |
| Event-driven hybrid (Event Grid -> Run Indexer) | Near real-time with managed enrichment | High | Indexer still handles consistency |
| Logic Apps connector pipeline (preview) | Broad SaaS/data connector coverage | Medium-High | Depends on connector + flow logic |

## 1. Indexer Pull Model (Managed)

Use a Search indexer to pull from supported sources and populate the index.

Typical sources:
- Azure Blob Storage
- ADLS Gen2
- Azure SQL / SQL MI
- Cosmos DB
- OneLake
- SharePoint Online (preview)

Why use it:
- Least custom code
- Native scheduling (as often as every 5 minutes)
- Built-in enrichment pipeline support

## 2. Indexer + Integrated Vectorization (Managed, Recommended for RAG)

Use:
- Data source + indexer
- Skillset for cracking/chunking/embedding
- Vector fields + vectorizer for query-time text-to-vector

Why use it:
- End-to-end managed ingestion + vector search
- Fewer moving parts than custom embedding pipelines
- Easy to keep synchronized on schedule

## 3. Push API / SDK Ingestion (Custom-Controlled)

Use `Documents - Index` APIs (or SDK equivalents) to push documents directly into your index.

Why use it:
- Full control over transformations and timing
- Works with any source if you can map data to index schema

Tradeoff:
- You must handle incremental sync, retries, and delete propagation yourself.

## 4. Event-Driven Hybrid (Low-Latency Managed)

Pattern:
- Source event (for example Blob event) triggers an app/workflow
- App calls `Run Indexer`
- Indexer performs managed enrichment/indexing

Why use it:
- Lower freshness latency than schedule-only
- Keeps Search-native pipeline benefits

## 5. Logic Apps Connector Pipeline (Preview)

Use Logic Apps connectors to bridge non-native sources into a Search indexing/enrichment pipeline.

Why use it:
- Broad connector ecosystem
- Low-code orchestration

Tradeoff:
- More orchestration complexity than pure indexer model
- Preview features may have limitations

## Update and Delete Strategy

- For indexers:
  - Change detection is automatic for supported sources.
  - Configure delete detection from day 0 (for Blob, prefer native soft delete pattern).
- For push model:
  - Use idempotent upserts (`mergeOrUpload`) and explicit `delete` actions.
  - Maintain your own source-of-truth watermark/checkpointing.

## Recommendation

For `PDF`, `DOCX`, `XLSX`, `TXT`, and `JSON` from Blob Storage:
- Start with **Indexer + Integrated Vectorization**.
- Add event-driven `Run Indexer` if you need faster freshness.
- Use push model only when business logic requires custom ingestion control.

## References

- [Indexer overview](https://learn.microsoft.com/en-us/azure/search/search-indexer-overview)
- [Supported Blob document formats and blob indexer](https://learn.microsoft.com/en-us/azure/search/search-how-to-index-azure-blob-storage)
- [Schedule indexers](https://learn.microsoft.com/en-us/azure/search/search-howto-schedule-indexers)
- [Detect changed and deleted blobs](https://learn.microsoft.com/en-us/azure/search/search-howto-index-changed-deleted-blobs)
- [Integrated vectorization](https://learn.microsoft.com/en-us/azure/search/vector-search-integrated-vectorization)
- [Generate embeddings (integrated vs manual)](https://learn.microsoft.com/en-us/azure/search/vector-search-how-to-generate-embeddings)
- [Load an index with push APIs](https://learn.microsoft.com/en-us/azure/search/search-how-to-load-search-index)
- [Vector index ingestion (push and pull)](https://learn.microsoft.com/en-us/azure/search/vector-search-how-to-create-index)
- [Run or reset indexers](https://learn.microsoft.com/en-us/azure/search/search-howto-run-reset-indexers)
- [SharePoint indexer (preview)](https://learn.microsoft.com/en-us/azure/search/search-howto-index-sharepoint-online)
- [Feature list (Logic Apps connector pipeline mention)](https://learn.microsoft.com/en-us/azure/search/search-features-list)
