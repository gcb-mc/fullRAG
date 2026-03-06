// ---------------------------------------------------------------------------
// Module: ai-foundry.bicep
// Creates: AI Hub + AI Project (Agent Service) + Capability Host
// Phase: 3 — AI & Data Services
// ---------------------------------------------------------------------------

param location string
param prefix string
param resourceToken string
param tags object

// Dependent resource IDs
param keyVaultId string
param storageAccountId string
param containerRegistryId string
param appInsightsId string
param aiServicesId string
param aiServicesName string
param aiSearchId string
param aiSearchName string

var aiHubName = 'aihub-${prefix}-${resourceToken}'
var aiProjectName = 'aiproj-${prefix}-${resourceToken}'

// Reference existing AI Services for connection
resource aiServicesRef 'Microsoft.CognitiveServices/accounts@2024-10-01' existing = {
  name: aiServicesName
}

// ---------------------------------------------------------------------------
// AI Hub (parent workspace)
// ---------------------------------------------------------------------------
resource aiHub 'Microsoft.MachineLearningServices/workspaces@2024-10-01' = {
  name: aiHubName
  location: location
  tags: tags
  kind: 'Hub'
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: 'ATLAS RAG AI Hub'
    description: 'AI Hub for ATLAS-RAG SharePoint Agent'
    keyVault: keyVaultId
    storageAccount: storageAccountId
    containerRegistry: containerRegistryId
    applicationInsights: appInsightsId
    managedNetwork: {
      isolationMode: 'AllowInternetOutbound'
    }
  }
}

// AI Services connection on the Hub
resource aiServicesConnection 'Microsoft.MachineLearningServices/workspaces/connections@2024-10-01' = {
  parent: aiHub
  name: 'aoai-connection'
  properties: {
    category: 'AzureOpenAI'
    authType: 'AAD'
    isSharedToAll: true
    target: aiServicesRef.properties.endpoint
    metadata: {
      ApiType: 'Azure'
      ResourceId: aiServicesId
    }
  }
}

// ---------------------------------------------------------------------------
// AI Project (child of Hub — hosts agents)
// ---------------------------------------------------------------------------
resource aiProject 'Microsoft.MachineLearningServices/workspaces@2024-10-01' = {
  name: aiProjectName
  location: location
  tags: tags
  kind: 'Project'
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: 'ATLAS RAG Agent Project'
    description: 'Agent project for ATLAS-RAG SharePoint retrieval'
    hubResourceId: aiHub.id
  }
}

// ---------------------------------------------------------------------------
// Agent Connections on the Project
// ---------------------------------------------------------------------------

// AI Search connection (vector store)
resource searchConnection 'Microsoft.MachineLearningServices/workspaces/connections@2024-10-01' = {
  parent: aiProject
  name: 'ai-search-connection'
  properties: {
    category: 'CognitiveSearch'
    authType: 'AAD'
    isSharedToAll: true
    target: 'https://${aiSearchName}.search.windows.net'
    metadata: {
      ResourceId: aiSearchId
      ApiType: 'Azure'
    }
  }
}

// ---------------------------------------------------------------------------
// NOTE: Capability Host for agents is created via Azure AI Foundry portal.
// Go to ai.azure.com → select project → Agents → Set up agents.
// ---------------------------------------------------------------------------

// Outputs
output aiHubName string = aiHub.name
output aiHubId string = aiHub.id
output aiHubPrincipalId string = aiHub.identity.principalId
output aiProjectName string = aiProject.name
output aiProjectId string = aiProject.id
output aiProjectPrincipalId string = aiProject.identity.principalId
output aiProjectEndpoint string = 'https://${aiProject.name}.${location}.api.azureml.ms'
