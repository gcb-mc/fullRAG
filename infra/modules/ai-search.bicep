// ---------------------------------------------------------------------------
// Module: ai-search.bicep
// Creates: Azure AI Search Service with hybrid + semantic ranking
// Phase: 3 — AI & Data Services
// ---------------------------------------------------------------------------

param location string
param prefix string
param resourceToken string
param tags object
param isProd bool

var searchServiceName = 'srch-${prefix}-${resourceToken}'

resource searchService 'Microsoft.Search/searchServices@2024-06-01-preview' = {
  name: searchServiceName
  location: location
  tags: tags
  sku: {
    name: isProd ? 'standard' : 'free'
  }
  properties: {
    replicaCount: isProd ? 2 : 1
    partitionCount: 1
    hostingMode: 'default'
    semanticSearch: isProd ? 'standard' : 'free'
    authOptions: {
      aadOrApiKey: {
        aadAuthFailureMode: 'http401WithBearerChallenge'
      }
    }
    publicNetworkAccess: isProd ? 'disabled' : 'enabled'
  }
}

// Outputs
output searchServiceId string = searchService.id
output searchServiceName string = searchService.name
output searchServiceEndpoint string = 'https://${searchService.name}.search.windows.net'
