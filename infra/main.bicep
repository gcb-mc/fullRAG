targetScope = 'subscription'

// ---------------------------------------------------------------------------
// Parameters
// ---------------------------------------------------------------------------
@minLength(1)
@maxLength(64)
@description('Name of the environment (e.g., rag-test-dev, rag-test-prod)')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string = 'eastus2'

// ---------------------------------------------------------------------------
// Variables
// ---------------------------------------------------------------------------
var isProd = contains(environmentName, 'prod')
var resourceToken = take(uniqueString(subscription().id, environmentName, location), 6)
var prefix = environmentName
var tags = {
  'azd-env-name': environmentName
  project: 'atlas-rag'
  environment: isProd ? 'prod' : 'dev'
}

// ---------------------------------------------------------------------------
// Resource Group
// ---------------------------------------------------------------------------
resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
}

// ---------------------------------------------------------------------------
// Phase 2 — Shared Services
// ---------------------------------------------------------------------------
module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoring'
  scope: rg
  params: {
    location: location
    prefix: prefix
    resourceToken: resourceToken
    tags: tags
    isProd: isProd
  }
}

module identity 'modules/managed-identity.bicep' = {
  name: 'managed-identity'
  scope: rg
  params: {
    location: location
    prefix: prefix
    resourceToken: resourceToken
    tags: tags
  }
}

module keyVault 'modules/key-vault.bicep' = {
  name: 'key-vault'
  scope: rg
  params: {
    location: location
    prefix: prefix
    resourceToken: resourceToken
    tags: tags
    isProd: isProd
  }
}

module containerRegistry 'modules/container-registry.bicep' = {
  name: 'container-registry'
  scope: rg
  params: {
    location: location
    prefix: prefix
    resourceToken: resourceToken
    tags: tags
    isProd: isProd
  }
}

// ---------------------------------------------------------------------------
// Phase 3 — AI & Data Services
// ---------------------------------------------------------------------------
module storageAccount 'modules/storage-account.bicep' = {
  name: 'storage-account'
  scope: rg
  params: {
    location: location
    prefix: prefix
    resourceToken: resourceToken
    tags: tags
    isProd: isProd
  }
}

module aiServices 'modules/ai-services.bicep' = {
  name: 'ai-services'
  scope: rg
  params: {
    location: location
    prefix: prefix
    resourceToken: resourceToken
    tags: tags
    isProd: isProd
  }
}

module aiSearch 'modules/ai-search.bicep' = {
  name: 'ai-search'
  scope: rg
  params: {
    location: location
    prefix: prefix
    resourceToken: resourceToken
    tags: tags
    isProd: isProd
  }
}

module cosmosDb 'modules/cosmos-db.bicep' = {
  name: 'cosmos-db'
  scope: rg
  params: {
    location: location
    prefix: prefix
    resourceToken: resourceToken
    tags: tags
    isProd: isProd
  }
}

module aiFoundry 'modules/ai-foundry.bicep' = {
  name: 'ai-foundry'
  scope: rg
  params: {
    location: location
    prefix: prefix
    resourceToken: resourceToken
    tags: tags
    keyVaultId: keyVault.outputs.keyVaultId
    storageAccountId: storageAccount.outputs.storageAccountId
    containerRegistryId: containerRegistry.outputs.containerRegistryId
    appInsightsId: monitoring.outputs.appInsightsId
    aiServicesId: aiServices.outputs.aiServicesId
    aiServicesName: aiServices.outputs.aiServicesName
    aiSearchId: aiSearch.outputs.searchServiceId
    aiSearchName: aiSearch.outputs.searchServiceName
  }
}

// ---------------------------------------------------------------------------
// Phase 4 — Compute
// ---------------------------------------------------------------------------
module containerApps 'modules/container-apps.bicep' = {
  name: 'container-apps'
  scope: rg
  params: {
    location: location
    prefix: prefix
    resourceToken: resourceToken
    tags: tags
    isProd: isProd
    identityId: identity.outputs.identityId
    identityClientId: identity.outputs.identityClientId
    containerRegistryLoginServer: containerRegistry.outputs.containerRegistryLoginServer
    appInsightsConnectionString: monitoring.outputs.appInsightsConnectionString
    logAnalyticsCustomerId: monitoring.outputs.logAnalyticsCustomerId
    logAnalyticsSharedKey: monitoring.outputs.logAnalyticsSharedKey
    cosmosEndpoint: cosmosDb.outputs.cosmosEndpoint
    searchEndpoint: aiSearch.outputs.searchServiceEndpoint
    aiProjectEndpoint: aiFoundry.outputs.aiProjectEndpoint
    keyVaultUri: keyVault.outputs.keyVaultUri
  }
}

// ---------------------------------------------------------------------------
// Phase 5 — Security (RBAC)
// ---------------------------------------------------------------------------
module security 'modules/security.bicep' = {
  name: 'security'
  scope: rg
  params: {
    principalId: identity.outputs.identityPrincipalId
    aiHubPrincipalId: aiFoundry.outputs.aiHubPrincipalId
    aiProjectPrincipalId: aiFoundry.outputs.aiProjectPrincipalId
    keyVaultName: keyVault.outputs.keyVaultName
    cosmosAccountName: cosmosDb.outputs.cosmosAccountName
    searchServiceName: aiSearch.outputs.searchServiceName
    aiServicesName: aiServices.outputs.aiServicesName
    storageAccountName: storageAccount.outputs.storageAccountName
    containerRegistryName: containerRegistry.outputs.containerRegistryName
    aiHubName: aiFoundry.outputs.aiHubName
    aiProjectName: aiFoundry.outputs.aiProjectName
  }
}

// ---------------------------------------------------------------------------
// Outputs (required by AZD)
// ---------------------------------------------------------------------------
output AZURE_RESOURCE_GROUP string = rg.name
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerRegistry.outputs.containerRegistryLoginServer
output AZURE_KEY_VAULT_NAME string = keyVault.outputs.keyVaultName
output AZURE_COSMOS_ENDPOINT string = cosmosDb.outputs.cosmosEndpoint
output AZURE_SEARCH_ENDPOINT string = aiSearch.outputs.searchServiceEndpoint
output AZURE_AI_PROJECT_ENDPOINT string = aiFoundry.outputs.aiProjectEndpoint
output AZURE_AI_SERVICES_ENDPOINT string = aiServices.outputs.aiServicesEndpoint
output API_URL string = containerApps.outputs.apiUrl
