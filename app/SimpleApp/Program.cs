using Azure.Identity;
using Azure.Security.KeyVault.Secrets;

var builder = WebApplication.CreateBuilder(args);

// Reads from App Service settings; set KEY_VAULT_NAME as an app setting in the Bicep/deployment,
// not as a secret — the vault name itself isn't sensitive.
var keyVaultName = builder.Configuration["KEY_VAULT_NAME"];

// Registered as SecretClient (not SecretClient?) so the generic `class` constraint on
// AddSingleton<TService> is satisfied; the null-forgiving return below is intentional —
// /config/status (further down) is the code that actually handles the null case.
builder.Services.AddSingleton<SecretClient>(sp =>
{
    if (string.IsNullOrWhiteSpace(keyVaultName))
    {
        return null!;
    }

    // DefaultAzureCredential picks up the App Service system-assigned managed identity in Azure,
    // and falls back to `az login` locally — no secrets in config, ever.
    var vaultUri = new Uri($"https://{keyVaultName}.vault.azure.net/");
    return new SecretClient(vaultUri, new DefaultAzureCredential());
});

var app = builder.Build();

// Liveness/readiness probe — also what the pipeline's post-deploy smoke test hits.
app.MapGet("/healthz", () => Results.Ok(new
{
    status = "healthy",
    timestampUtc = DateTime.UtcNow
}));

// Demonstrates the managed-identity-to-Key-Vault pattern without exposing secret *values*.
app.MapGet("/config/status", (SecretClient? secretClient) =>
{
    if (secretClient is null)
    {
        return Results.Ok(new { keyVaultConnected = false, reason = "KEY_VAULT_NAME not configured" });
    }

    try
    {
        // Just confirms connectivity/identity works; does not return the secret value.
        _ = secretClient.GetPropertiesOfSecretsAsync();
        return Results.Ok(new { keyVaultConnected = true });
    }
    catch (Exception ex)
    {
        return Results.Problem($"Key Vault connectivity check failed: {ex.Message}");
    }
});

app.MapGet("/", () => Results.Ok(new
{
    service = "jmalabuk-simpleapp",
    message = "Golden-path sample workload — see /healthz and /config/status"
}));

app.Run();
