// Subscription-scope orchestrator for the jmalabuk dev landing zone.
// Deploy with:
//   az deployment sub create --name main-wcus --location westcentralus --template-file main.bicep \
//     --parameters parameters/dev.bicepparam

targetScope = 'subscription'

@description('Environment name, used in resource naming and tagging')
param environmentName string = 'dev-wcus'

@description('Azure region for all resources')
param location string = 'westcentralus'

@description('Custom domain to bind to the App Service')
param customDomain string = 'jmalabuk.uk'

@description('Optional override for the Key Vault name, for when the default name is stuck soft-deleted from a previous deploy')
param keyVaultNameOverride string = ''

var rgName = 'rg-jmalabuk-${environmentName}'
var tags = {
  project: 'jmalabuk-security-platform-lab'
  environment: environmentName
  owner: 'platform-security'
  costCentre: 'free-tier-lab'
}

resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: rgName
  location: location
  tags: tags
}

module policy 'modules/policy.bicep' = {
  name: 'policy-assignments'
  scope: rg
}

module network 'modules/network.bicep' = {
  name: 'network'
  scope: rg
  params: {
    location: location
    tags: tags
  }
}

module logAnalytics 'modules/loganalytics.bicep' = {
  name: 'log-analytics'
  scope: rg
  params: {
    location: location
    tags: tags
  }
}

module keyVault 'modules/keyvault.bicep' = {
  name: 'key-vault'
  scope: rg
  params: {
    location: location
    tags: tags
    vaultNameOverride: keyVaultNameOverride
  }
}

module appService 'modules/appservice.bicep' = {
  name: 'app-service'
  scope: rg
  params: {
    location: location
    tags: tags
    keyVaultName: keyVault.outputs.keyVaultName
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
    customDomain: customDomain
  }
}

output resourceGroupName string = rg.name
output appServiceDefaultHostName string = appService.outputs.defaultHostName
output keyVaultName string = keyVault.outputs.keyVaultName
