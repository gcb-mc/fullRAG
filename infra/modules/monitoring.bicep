// ---------------------------------------------------------------------------
// Module: monitoring.bicep
// Creates: Log Analytics Workspace + Application Insights
// Phase: 2 — Shared Services
// ---------------------------------------------------------------------------

param location string
param prefix string
param resourceToken string
param tags object
param isProd bool

var logAnalyticsName = 'log-${prefix}-${resourceToken}'
var appInsightsName = 'appi-${prefix}-${resourceToken}'

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: isProd ? 90 : 30
  }
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
}

// Outputs
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
output logAnalyticsCustomerId string = logAnalyticsWorkspace.properties.customerId

@description('Log Analytics shared key — used by Container Apps Environment for log ingestion')
#disable-next-line outputs-should-not-contain-secrets
output logAnalyticsSharedKey string = logAnalyticsWorkspace.listKeys().primarySharedKey
output appInsightsId string = applicationInsights.id
output appInsightsConnectionString string = applicationInsights.properties.ConnectionString
output appInsightsInstrumentationKey string = applicationInsights.properties.InstrumentationKey
