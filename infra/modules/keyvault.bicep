@description('Azure region')
param location string

@description('Tags to apply to all resources')
param tags object

@description('Optional override for the Key Vault name. Leave blank to use the default (uniqueString-based) name. Set this if that default name is stuck in a soft-deleted/purge-protected state from a previous deploy.')
param vaultNameOverride string = ''

// uniqueString(), not a fixed literal: Key Vault names must be globally unique across all of
// Azure. Deterministic per resource group, so redeploys target the same vault.
// No 'kv-' prefix: vault names are capped at 24 chars, and 'jmalabuk-' + uniqueString's 13
// chars already uses 22 of them.
var defaultVaultName = 'jmalabuk-${uniqueString(resourceGroup().id)}'
var vaultName = empty(vaultNameOverride) ? defaultVaultName : vaultNameOverride

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: vaultName
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true // RBAC, not vault access policies — consistent with the rest of the estate
    enableSoftDelete: true // mandatory on Key Vault now — Azure no longer allows disabling it
    softDeleteRetentionInDays: 7
    // enablePurgeProtection intentionally omitted, not set to false: it defaults to off for a
    // new vault (lets a deleted vault's name be freed immediately via 'az keyvault purge' instead
    // of waiting out the 7-day retention window), but it's a one-way switch once true on an
    // existing vault — Azure rejects an explicit 'false' as an illegal downgrade. A real/
    // production vault should set this to true.
    networkAcls: {
      defaultAction: 'Allow' // lab-scale; a real landing zone would set this to Deny + private endpoint
      bypass: 'AzureServices'
    }
  }
}

output keyVaultName string = keyVault.name
output keyVaultId string = keyVault.id
