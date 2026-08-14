using '../main.bicep'

param environmentName = 'dev-wcus'
param location = 'westcentralus'
param customDomain = 'jmalabuk.uk'
// Set this if the default Key Vault name is stuck soft-deleted from a previous deploy,
// e.g. param keyVaultNameOverride = 'jmalabuk-v2'
// Left blank: this is a fresh resource group (rg-jmalabuk-dev-wcus), so the default
// uniqueString(resourceGroup().id) name is guaranteed not to collide with the old
// uksouth vault (jmalabuk-v2), which is a different resource group entirely.
param keyVaultNameOverride = ''
