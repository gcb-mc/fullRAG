// ---------------------------------------------------------------------------
// Module: cosmos-db.bicep
// Creates: Cosmos DB account (NoSQL) + database + containers for thread storage
// Phase: 3 — AI & Data Services
// ---------------------------------------------------------------------------

param location string
param prefix string
param resourceToken string
param tags object
param isProd bool

var cosmosAccountName = 'cosmos-${prefix}-${resourceToken}'
var databaseName = 'atlas-rag-db'

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' = {
  name: cosmosAccountName
  location: location
  tags: tags
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: isProd
      }
    ]
    capabilities: isProd ? [] : [
      {
        name: 'EnableServerless'
      }
    ]
    publicNetworkAccess: isProd ? 'Disabled' : 'Enabled'
    isVirtualNetworkFilterEnabled: isProd
    disableLocalAuth: false // Enable RBAC-based auth alongside keys
  }
}

resource database 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-05-15' = {
  parent: cosmosAccount
  name: databaseName
  properties: {
    resource: {
      id: databaseName
    }
  }
}

// Container: threads (stores conversation threads)
resource threadsContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = {
  parent: database
  name: 'threads'
  properties: {
    resource: {
      id: 'threads'
      partitionKey: {
        paths: ['/userId']
        kind: 'Hash'
        version: 2
      }
      defaultTtl: -1 // No expiration
      indexingPolicy: {
        indexingMode: 'consistent'
        automatic: true
        includedPaths: [{ path: '/*' }]
        excludedPaths: [{ path: '/_etag/?' }]
      }
    }
    options: isProd ? {
      autoscaleSettings: {
        maxThroughput: 4000
      }
    } : {}
  }
}

// Container: conversations (stores individual messages within threads)
resource conversationsContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = {
  parent: database
  name: 'conversations'
  properties: {
    resource: {
      id: 'conversations'
      partitionKey: {
        paths: ['/threadId']
        kind: 'Hash'
        version: 2
      }
      defaultTtl: -1
      indexingPolicy: {
        indexingMode: 'consistent'
        automatic: true
        includedPaths: [{ path: '/*' }]
        excludedPaths: [{ path: '/_etag/?' }]
      }
    }
    options: isProd ? {
      autoscaleSettings: {
        maxThroughput: 4000
      }
    } : {}
  }
}

// Outputs
output cosmosAccountName string = cosmosAccount.name
output cosmosAccountId string = cosmosAccount.id
output cosmosEndpoint string = cosmosAccount.properties.documentEndpoint
output cosmosDatabaseName string = database.name
