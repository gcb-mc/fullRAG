// ---------------------------------------------------------------------------
// Module: storage-account.bicep
// Creates: Azure Storage Account (for AI Foundry file storage)
// Phase: 3 — AI & Data Services
// ---------------------------------------------------------------------------

param location string
@minLength(1)
param prefix string
@minLength(1)
param resourceToken string
param tags object
param isProd bool

// Storage account names: alphanumeric only, 3-24 chars
// 'st' prefix (2 chars) + prefix + resourceToken guarantees min length > 3
var storageAccountName = take(replace('st${prefix}${resourceToken}', '-', ''), 24)

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: isProd ? 'Standard_ZRS' : 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true // Required for AI Foundry connections
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    publicNetworkAccess: isProd ? 'Disabled' : 'Enabled'
    networkAcls: {
      defaultAction: isProd ? 'Deny' : 'Allow'
      bypass: 'AzureServices'
    }
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
}

resource agentFilesContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'agent-files'
  properties: {
    publicAccess: 'None'
  }
}

// Outputs
output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
output storageBlobEndpoint string = storageAccount.properties.primaryEndpoints.blob
