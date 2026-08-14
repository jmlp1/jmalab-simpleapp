// Built-in policy definition IDs (Azure Policy's public "Deny" set) — reused rather than
// re-authored, per the "policy as code, not policy as wiki page" principle.
var requireHttpsPolicyId = tenantResourceId('Microsoft.Authorization/policyDefinitions', 'a4af4a39-4135-47fb-b175-47fbdf85311d') // App Service should require HTTPS
var minTlsPolicyId = tenantResourceId('Microsoft.Authorization/policyDefinitions', 'f0e6e85b-9b9f-4a4b-b67b-f730d42f1b0b') // App Service min TLS version
var noPublicIpPolicyId = tenantResourceId('Microsoft.Authorization/policyDefinitions', '83a86a26-fd1f-447c-b59d-e51f44264114') // Storage/PaaS resources should restrict public network access
var requireTagPolicyId = tenantResourceId('Microsoft.Authorization/policyDefinitions', '871b6d14-10aa-478d-b590-94f262ecfa99') // Require a tag on resource groups

resource requireHttps 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: 'deny-appservice-no-https'
  properties: {
    displayName: 'Deny App Service without HTTPS-only enforced'
    policyDefinitionId: requireHttpsPolicyId
    enforcementMode: 'Default'
  }
}

resource minTls 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: 'deny-appservice-weak-tls'
  properties: {
    displayName: 'Deny App Service below TLS 1.2'
    policyDefinitionId: minTlsPolicyId
    enforcementMode: 'Default'
  }
}

resource requireOwnerTag 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: 'require-owner-tag'
  properties: {
    displayName: 'Require owner tag on this resource group'
    policyDefinitionId: requireTagPolicyId
    parameters: {
      tagName: {
        value: 'owner'
      }
    }
    enforcementMode: 'Default'
  }
}

// noPublicIpPolicyId is not assigned yet: it belongs on a real (non-F1) tier where Key
// Vault/Storage sit behind private endpoints, which F1 App Service can't reach. Exposed as
// an output below (rather than left as a dangling var) so it's ready to assign once that
// tier change happens. See docs/ROADMAP.md.

output assignedPolicyIds array = [
  requireHttps.id
  minTls.id
  requireOwnerTag.id
]

output deferredPolicyIds object = {
  noPublicIpPolicyId: noPublicIpPolicyId
}
