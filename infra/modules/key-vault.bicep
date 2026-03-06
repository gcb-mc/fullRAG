// ---------------------------------------------------------------------------
// Module: key-vault.bicep
// Creates: Azure Key Vault with RBAC authorization
// Phase: 2 — Shared Services
// ---------------------------------------------------------------------------

param location string
param prefix string
param resourceToken string
param tags object
param isProd bool

var keyVaultName = take('kv-${prefix}-${resourceToken}', 24)

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    enableSoftDelete: true
    enablePurgeProtection: isProd ? true : null
    enabledForTemplateDeployment: true
    softDeleteRetentionInDays: 90
    networkAcls: {
      defaultAction: isProd ? 'Deny' : 'Allow'
      bypass: 'AzureServices'
    }
  }
}

// Outputs
output keyVaultId string = keyVault.id
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
