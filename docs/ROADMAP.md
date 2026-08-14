# From lab to platform

This lab is deliberately small. Here's the honest list of what's simplified for the free tier,
and what the next increment would be if this became a real Internal Developer Platform.

## Known free-tier simplifications

| Area | Lab state | Real-world next step |
|---|---|---|
| App Service tier | F1 (Free) | Move to B1+/P-tier for custom-domain SSL binding and staging slots |
| Key Vault network | Public endpoint, `AzureServices` bypass | Private endpoint + `Deny` default network ACL once compute can reach it privately |
| Multi-tenant isolation | Single resource group, single app | One resource group *per product team*, deployed from the same golden-path template — this repo becomes the template, not the tenant |
| Policy scope | Assigned at resource-group scope for one RG | Assigned at management-group scope so every new landing zone inherits it automatically |
| DAST target | Single post-deploy ZAP baseline scan | Scheduled recurring scans + authenticated scan profile for endpoints behind auth |
| Evidence retention | 30-day Log Analytics retention | Export to immutable storage (WORM) for audit retention requirements |
| Identity federation | One OIDC federated credential for one repo | Federated credential subject scoped per environment/branch, GitHub OIDC trust configured centrally so product teams don't each set this up themselves |

## From one repo to a golden path

The next real increment isn't more resources — it's turning this repo into a **template repo**
(`gh repo create --template`) with a lightweight generator (a `dotnet new` template or a
`Copier`/`cookiecutter`-style generator) so a product team runs one command and gets:

- a repo with the pipeline, Dependabot config, and branch protection already applied,
- a Bicep module reference back to a *shared* landing-zone module registry (so they're not
  copy-pasting `infra/modules/*` — they're consuming versioned modules),
- an entry in the platform's service catalog, which is what feeds the "adoption" metric in the
  platform-as-a-product model.

## Metrics this platform would want to track

In line with "measuring success by adoption and reduced friction, not just controls shipped":

- **Time from `template use` to first successful deploy** (lead time for the golden path itself)
- **% of repos using the template vs. bespoke pipelines** (adoption)
- **Policy exception rate** — how often teams need a waiver, which is a proxy for whether the
  golden path is actually the easy path
- **Mean time to remediate a High/Critical SARIF finding** (not just "was it scanned")
