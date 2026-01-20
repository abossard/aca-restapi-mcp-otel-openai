#!/bin/bash
# Create the 'documents' index in Azure AI Search
# Usage: ./create-search-index.sh <search-service-name> <resource-group>

set -e

SEARCH_SERVICE="${1:-aca-restapi-v2-search-mcpai}"
RG="${2:-rg-aca-restapi-v2-mcpai}"
INDEX_NAME="${3:-documents}"

echo "Getting Azure AD access token..."
ACCESS_TOKEN=$(az account get-access-token --resource "https://search.azure.com" --query "accessToken" -o tsv)

if [ -z "$ACCESS_TOKEN" ]; then
    echo "ERROR: Could not retrieve access token"
    exit 1
fi

echo "Creating index '$INDEX_NAME' in $SEARCH_SERVICE..."
RESPONSE=$(curl -s -w "\n%{http_code}" -X PUT \
    "https://${SEARCH_SERVICE}.search.windows.net/indexes/${INDEX_NAME}?api-version=2024-07-01" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -d '{
        "name": "'"${INDEX_NAME}"'",
        "fields": [
            {"name": "id", "type": "Edm.String", "key": true, "searchable": false},
            {"name": "content", "type": "Edm.String", "searchable": true, "analyzer": "standard.lucene"},
            {"name": "title", "type": "Edm.String", "searchable": true},
            {"name": "source", "type": "Edm.String", "filterable": true, "searchable": false}
        ]
    }')

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 200 ] || [ "$HTTP_CODE" -eq 201 ] || [ "$HTTP_CODE" -eq 204 ]; then
    echo "✅ Index '$INDEX_NAME' created/updated successfully (HTTP $HTTP_CODE)"
else
    echo "❌ Failed to create index. HTTP $HTTP_CODE"
    echo "$BODY"
    exit 1
fi
