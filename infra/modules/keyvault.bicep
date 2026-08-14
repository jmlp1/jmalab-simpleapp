@description('Azure region')
param location string

@description('Tags to apply to all resources')
param tags object

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: 'kv-jmalab-${uniqueString(resourceGroup().id)}'
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true // RBAC, not vault access policies — consistent with the rest of the estate
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    enablePurgeProtection: true
    networkAcls: {
      defaultAction: 'Allow' // lab-scale; a real landing zone would set this to Deny + private endpoint
      bypass: 'AzureServices'
    }
  }
}

output keyVaultName string = keyVault.name
output keyVaultId string = keyVault.id
