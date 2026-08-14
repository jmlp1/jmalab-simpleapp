@description('Azure region')
param location string

@description('Tags to apply to all resources')
param tags object

resource workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'law-jmalabuk'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018' // billed only past the 5GB/month free grant — fine at lab scale
    }
    retentionInDays: 30
  }
}

output workspaceId string = workspace.id
output workspaceName string = workspace.name
