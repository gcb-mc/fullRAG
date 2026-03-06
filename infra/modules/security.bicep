// ---------------------------------------------------------------------------
// Module: security.bicep
// Creates: All RBAC role assignments (centralized for auditability)
// Phase: 5 — Security
// ---------------------------------------------------------------------------

param principalId string
param aiHubPrincipalId string
param aiProjectPrincipalId string

// Resource names (used to reference existing resources for scoping)
param keyVaultName string
param cosmosAccountName string
param searchServiceName string
param aiServicesName string
param storageAccountName string
param containerRegistryName string
param aiHubName string
param aiProjectName string

// ---------------------------------------------------------------------------
// Built-in Role Definition IDs
// https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles
// ---------------------------------------------------------------------------
var roles = {
  keyVaultSecretsUser: '4633458b-17de-408a-b874-0445c86b69e6'
  searchIndexDataReader: '1407120a-92aa-4202-b7e9-c0e197c71c8f'
  cognitiveServicesOpenAiUser: '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
  storageBlobDataContributor: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  acrPull: '7f951dda-4ed3-4680-a7ca-43fe172d538d'
  azureAiUser: 'acdd72a7-3385-48ef-bd42-f606fba81ae7' // Reader — used for AI workspace access
  searchIndexDataContributor: '8ebe5a00-799e-43f5-93ac-243d3dce84a7'
}

// ---------------------------------------------------------------------------
// Reference existing resources
// ---------------------------------------------------------------------------
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' existing = {
  name: cosmosAccountName
}

resource searchService 'Microsoft.Search/searchServices@2024-06-01-preview' existing = {
  name: searchServiceName
}

resource aiServices 'Microsoft.CognitiveServices/accounts@2024-10-01' existing = {
  name: aiServicesName
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: containerRegistryName
}

resource aiHub 'Microsoft.MachineLearningServices/workspaces@2024-10-01' existing = {
  name: aiHubName
}

resource aiProject 'Microsoft.MachineLearningServices/workspaces@2024-10-01' existing = {
  name: aiProjectName
}

// ---------------------------------------------------------------------------
// Role Assignments
// ---------------------------------------------------------------------------

// Key Vault Secrets User
resource kvSecretsUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, principalId, roles.keyVaultSecretsUser)
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.keyVaultSecretsUser)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

// Cosmos DB Built-in Data Contributor (uses Cosmos SQL Role Assignment API, not Azure RBAC)
// Built-in role ID: 00000000-0000-0000-0000-000000000002
var cosmosDataContributorRoleId = '${cosmosAccount.id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002'

resource cosmosDataContributorRole 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-05-15' = {
  parent: cosmosAccount
  name: guid(cosmosAccount.id, principalId, 'cosmos-data-contributor')
  properties: {
    roleDefinitionId: cosmosDataContributorRoleId
    principalId: principalId
    scope: cosmosAccount.id
  }
}

// Search Index Data Reader
resource searchReaderRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(searchService.id, principalId, roles.searchIndexDataReader)
  scope: searchService
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.searchIndexDataReader)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

// Cognitive Services OpenAI User
resource openAiUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiServices.id, principalId, roles.cognitiveServicesOpenAiUser)
  scope: aiServices
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.cognitiveServicesOpenAiUser)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

// Storage Blob Data Contributor
resource storageBlobContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, principalId, roles.storageBlobDataContributor)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.storageBlobDataContributor)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

// AcrPull
resource acrPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(containerRegistry.id, principalId, roles.acrPull)
  scope: containerRegistry
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.acrPull)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

// Azure AI User on Hub
resource aiHubUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiHub.id, principalId, roles.azureAiUser)
  scope: aiHub
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.azureAiUser)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

// Azure AI User on Project
resource aiProjectUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiProject.id, principalId, roles.azureAiUser)
  scope: aiProject
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.azureAiUser)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

// ---------------------------------------------------------------------------
// AI Hub System-Assigned Identity RBAC
// ---------------------------------------------------------------------------

// AI Hub → Storage Blob Data Contributor
resource aiHubStorageBlobRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, aiHubPrincipalId, roles.storageBlobDataContributor)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.storageBlobDataContributor)
    principalId: aiHubPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// AI Hub → Key Vault Secrets User
resource aiHubKvSecretsRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, aiHubPrincipalId, roles.keyVaultSecretsUser)
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.keyVaultSecretsUser)
    principalId: aiHubPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// AI Hub → ACR Pull
resource aiHubAcrPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(containerRegistry.id, aiHubPrincipalId, roles.acrPull)
  scope: containerRegistry
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.acrPull)
    principalId: aiHubPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// ---------------------------------------------------------------------------
// AI Project System-Assigned Identity RBAC
// ---------------------------------------------------------------------------

// AI Project → Cognitive Services OpenAI User
resource aiProjectOpenAiRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiServices.id, aiProjectPrincipalId, roles.cognitiveServicesOpenAiUser)
  scope: aiServices
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.cognitiveServicesOpenAiUser)
    principalId: aiProjectPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// AI Project → Storage Blob Data Contributor
resource aiProjectStorageBlobRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, aiProjectPrincipalId, roles.storageBlobDataContributor)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.storageBlobDataContributor)
    principalId: aiProjectPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// AI Project → Search Index Data Contributor (write access for agent vector store)
resource aiProjectSearchContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(searchService.id, aiProjectPrincipalId, roles.searchIndexDataContributor)
  scope: searchService
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.searchIndexDataContributor)
    principalId: aiProjectPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// AI Project → Cosmos DB Data Contributor (thread storage — uses Cosmos SQL Role Assignment API)
resource aiProjectCosmosRole 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-05-15' = {
  parent: cosmosAccount
  name: guid(cosmosAccount.id, aiProjectPrincipalId, 'cosmos-data-contributor')
  properties: {
    roleDefinitionId: cosmosDataContributorRoleId
    principalId: aiProjectPrincipalId
    scope: cosmosAccount.id
  }
}
