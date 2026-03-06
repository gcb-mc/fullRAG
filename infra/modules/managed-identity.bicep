// ---------------------------------------------------------------------------
// Module: managed-identity.bicep
// Creates: User-Assigned Managed Identity
// Phase: 2 — Shared Services
// ---------------------------------------------------------------------------

param location string
param prefix string
param resourceToken string
param tags object

var identityName = 'id-${prefix}-${resourceToken}'

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
  tags: tags
}

// Outputs
output identityId string = managedIdentity.id
output identityPrincipalId string = managedIdentity.properties.principalId
output identityClientId string = managedIdentity.properties.clientId
output identityName string = managedIdentity.name
