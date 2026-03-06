// ---------------------------------------------------------------------------
// Module: container-registry.bicep
// Creates: Azure Container Registry
// Phase: 2 — Shared Services
// ---------------------------------------------------------------------------

param location string
@minLength(1)
param prefix string
@minLength(1)
param resourceToken string
param tags object
param isProd bool

// ACR names must be alphanumeric only, 5-50 chars
// 'cr' prefix (2 chars) + prefix + resourceToken guarantees min length >= 5
var registryName = take(replace('cr${prefix}${resourceToken}', '-', ''), 50)

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: registryName
  location: location
  tags: tags
  sku: {
    name: isProd ? 'Premium' : 'Premium' // Premium required by AI Hub managed network
  }
  properties: {
    adminUserEnabled: false
  }
}

// Outputs
output containerRegistryId string = containerRegistry.id
output containerRegistryName string = containerRegistry.name
output containerRegistryLoginServer string = containerRegistry.properties.loginServer
