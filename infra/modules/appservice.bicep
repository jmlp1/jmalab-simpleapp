@description('Azure region')
param location string

@description('Tags to apply to all resources')
param tags object

@description('Key Vault name for RBAC role assignment')
param keyVaultName string

@description('Log Analytics workspace resource ID for diagnostic settings')
param logAnalyticsWorkspaceId string

@description('Custom domain to reference (actual binding is a post-deploy step — see docs/DOMAIN-SETUP.md)')
param customDomain string

var appName = 'app-jmalabuk-simpleapp'
var planName = 'plan-jmalabuk-free'

resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: planName
  location: location
  tags: tags
  sku: {
    name: 'F1' // Free tier. Was blocked by a 0-quota "Dedicated VMs" limit that Free Trial
               // subscriptions can't self-serve a quota increase for; needs a Pay-As-You-Go
               // upgrade to clear. Regional VNet integration and custom-domain SSL are not
               // available on F1 — see docs/ROADMAP.md for the upgrade path.
    tier: 'Free'
  }
  properties: {
    reserved: true // Linux plan, hosts the .NET 10 app
  }
}

resource app 'Microsoft.Web/sites@2023-12-01' = {
  name: appName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'DOTNETCORE|10.0'
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      http20Enabled: true
      appSettings: [
        {
          name: 'KEY_VAULT_NAME'
          value: keyVaultName
        }
      ]
    }
  }
}

resource diagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-to-law'
  scope: app
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'AppServiceHTTPLogs'
        enabled: true
      }
      {
        category: 'AppServiceConsoleLogs'
        enabled: true
      }
      {
        category: 'AppServiceAuditLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// Grant the app's managed identity read access to Key Vault secrets/certs (RBAC, no vault access policy)
resource kv 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource kvSecretsUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(kv.id, app.id, 'KeyVaultSecretsUser')
  scope: kv
  properties: {
    principalId: app.identity.principalId
    principalType: 'ServicePrincipal'
    // Key Vault Secrets User
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
  }
}

output defaultHostName string = app.properties.defaultHostName
output appName string = app.name
output principalId string = app.identity.principalId
output plannedCustomDomain string = customDomain
