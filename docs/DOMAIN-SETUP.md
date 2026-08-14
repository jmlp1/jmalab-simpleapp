# Binding `jmalabuk.uk` to the App Service

You said you already hold certs for `jmalabuk.uk`, so this assumes an existing `.pfx` rather than
provisioning one from Let's Encrypt/App Service Managed Certificates (which also isn't available
on the F1 Free tier — Managed Certificates need Basic or above).

## 1. DNS records

At your DNS provider for `jmalabuk.uk`, add:

| Type | Name | Value |
|---|---|---|
| CNAME | `app` (i.e. `app.jmalabuk.uk`) | `app-jmalabuk-simpleapp.azurewebsites.net` |
| TXT | `asuid.app` | `<domain verification ID from App Service → Custom domains>` |

Get the verification ID with:

```bash
az webapp show --resource-group rg-jmalabuk-dev --name app-jmalabuk-simpleapp \
  --query customDomainVerificationId -o tsv
```

## 2. Import the certificate to Key Vault

Keeping the private key in Key Vault (rather than uploading the `.pfx` directly to App Service)
is the pattern worth demonstrating here — it's the same mechanism a real platform would use for
managed cert rotation.

```bash
az keyvault certificate import \
  --vault-name <kv-name-from-deployment-output> \
  --name jmalabuk-uk-cert \
  --file /path/to/jmalabuk.uk.pfx \
  --password <pfx-password>
```

Grant the App Service's managed identity the `Key Vault Certificate User` role on the vault (in
addition to the `Key Vault Secrets User` role already assigned by `appservice.bicep`):

```bash
principalId=$(az webapp show --resource-group rg-jmalabuk-dev --name app-jmalabuk-simpleapp \
  --query identity.principalId -o tsv)

az role assignment create \
  --assignee-object-id "$principalId" \
  --assignee-principal-type ServicePrincipal \
  --role "Key Vault Certificate User" \
  --scope "$(az keyvault show --name <kv-name> --query id -o tsv)"
```

## 3. Bind the domain and certificate

```bash
az webapp config hostname add \
  --resource-group rg-jmalabuk-dev \
  --webapp-name app-jmalabuk-simpleapp \
  --hostname app.jmalabuk.uk

az webapp config ssl import \
  --resource-group rg-jmalabuk-dev \
  --name app-jmalabuk-simpleapp \
  --key-vault <kv-name> \
  --key-vault-certificate-name jmalabuk-uk-cert

az webapp config ssl bind \
  --resource-group rg-jmalabuk-dev \
  --name app-jmalabuk-simpleapp \
  --certificate-thumbprint <thumbprint-from-import-output> \
  --ssl-type SNI
```

## Known F1 (Free tier) limitation

Custom domain **SSL binding on the Free (F1) App Service plan is not supported by Azure** —
it requires at least the Shared or Basic tier. If you want the cert bound and serving HTTPS on
`app.jmalabuk.uk` directly (rather than the `.azurewebsites.net` default), the plan SKU needs to
move to `B1` (Basic), which has a small monthly cost. Two honest options for the lab:

1. **Stay on F1** and demonstrate the pattern using the default `azurewebsites.net` hostname —
   the Key Vault cert-import and RBAC pattern above is still fully real and demonstrable.
2. **Bump to B1** for the duration of a demo/interview only, then scale back to F1 — B1 is a few
   pounds/month, well within typical trial credits, and this is exactly the kind of "cost vs.
   control" trade-off worth being able to articulate.

This trade-off is deliberately left visible rather than hidden, because being explicit about
free-tier constraints vs. what a real environment needs is itself part of what the role is
asking for.
