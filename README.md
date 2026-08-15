# Secure Internal Developer Platform — Azure Lab

A small, cost-free (Azure free-tier) lab that demonstrates the operating model described in the
"Security Bridge / Platform Engineering" role: **secure-by-default golden paths, policy-as-code,
automated evidence, and agentic AI in the delivery pipeline** — built around one simple .NET app
so the whole loop (code → pipeline → policy gate → deploy → evidence) is visible end to end.

This isn't meant to be a production platform. It's a portfolio artefact: small enough to run on
a free-tier subscription, but structured the way a real IDP golden path would be, so every design
decision maps back to something you can talk about in an interview.

## What's in here

| Folder | Purpose | Maps to JD theme |
|---|---|---|
| `infra/` | Bicep modules for the landing zone (network, App Service, Key Vault, Log Analytics, Policy) | "Build and run the platform on Azure" |
| `app/SimpleApp` | Minimal .NET 10 API — the "product team" workload the platform hosts | Proof the golden path actually runs a real app |
| `.github/workflows` | CI/CD: build → SAST (CodeQL) → dependency/secret scanning → policy gate → apply infra → deploy → DAST (OWASP ZAP) | "Embed SAST/DAST into CI/CD... enforce as policy gates" |
| `.github/dependabot.yml` | Weekly dependency updates (NuGet + GitHub Actions versions) | Keeps the pipeline itself and app dependencies patched |
| `policies/` | Azure Policy-as-code definitions (deny-by-default guardrails) | "Guardrails as code... compliant by construction" |
| `docs/ARCHITECTURE.md` | System diagram + design rationale | "Represent posture to Security and audit" |
| `docs/DOMAIN-SETUP.md` | Binding `jmalabuk.uk` + TLS cert to the App Service | Custom domain / cert handling |
| `docs/AGENTIC-AI.md` | Where and how agentic AI is used in the workflow, with guardrails | "Apply agentic AI to security engineering" |
| `docs/ROADMAP.md` | How this scales from lab → real IDP | "Turn recurring needs into paved, supported capabilities" |

## Design principles this lab is built to demonstrate

1. **Golden path, not ticket path** — a product team creates a repo from a template, pushes code,
   and gets a secure, compliant Azure resource without opening a ticket to Security or Platform.
2. **Guardrails as code** — nothing is compliant by policy document; it's compliant because Azure
   Policy and pipeline gates physically block the non-compliant path.
3. **Evidence as a by-product** — every pipeline run emits SARIF (CodeQL), a policy compliance
   report, and a deployment manifest to Log Analytics. Audit reads dashboards, not spreadsheets.
4. **Free-tier discipline** — every resource SKU below is chosen to fit Azure's free tier / free
   grants, because the brief is "credits only."
5. **Agentic AI as a workflow participant, not a demo** — used for policy-authoring assistance and
   change-impact analysis, with human sign-off gates documented in `docs/AGENTIC-AI.md`.

## Free-tier resource choices

| Resource | SKU / Tier | Why |
|---|---|---|
| App Service Plan | **F1 (Free)** | Hosts the .NET app; free forever, 60 CPU-min/day cap is fine for a demo |
| Key Vault | **Standard**, minimal ops | Free tier has no monthly fee — only per-operation cost, negligible at this scale |
| Log Analytics Workspace | **Pay-as-you-go with 5GB/month free grant** | Central sink for pipeline evidence + diagnostic logs |
| Azure Policy | Included, no cost | Guardrails-as-code |
| Microsoft Entra ID | Free tier | App registration, managed identity, RBAC |
| Virtual Network | No cost for the VNet itself | Segregates the App Service via VNet integration (data-out charges are the only cost, and stay ~£0 at lab scale) |
| GitHub | Free plan, private repo | Free Actions minutes cover this pipeline. **Note:** GitHub Advanced Security (CodeQL Security-tab alerts, `dependency-review-action`) is org-only — it does not work on a personal private repo at all, at any price. The pipeline works around this: CodeQL still runs and gates the build, results just publish as a downloadable SARIF artifact instead of a Security-tab alert (see `.github/workflows/ci-cd.yml`). |

> ⚠️ Nothing here needs a paid Azure tier. If you later add Azure Front Door, WAF, or a paid App
> Service plan for staging slots, flag it — those are the first things that would burn credits.

## Quick start

```pwsh
# 1. Deploy the landing zone (first time only — see below for why this can't be
#    bootstrapped by the pipeline itself)
az deployment sub create `
  --name main-wcus `
  --location westcentralus `
  --template-file infra/main.bicep `
  --parameters infra/parameters/dev.bicepparam

# 2. Push app/ and .github/ to a new GitHub repo — the workflow deploys on push to main
git init && git remote add origin https://github.com/<you>/jmalabuk-simpleapp.git

# 3. Bind the custom domain — see docs/DOMAIN-SETUP.md
```

Step 1 is a **first-time-only bootstrap**. After that, `infra/` changes (App Service SKU, runtime
stack, Key Vault, policy assignments, etc.) are applied automatically by the pipeline's
`infra-deploy` job on every push to `main` — see "CI/CD pipeline setup" below. It can't bootstrap
itself because the Azure identity the pipeline uses to deploy has to be granted access *scoped to
a resource group that already exists*, which means the very first deployment has to happen by hand,
under your own login.

## CI/CD pipeline setup (one-time)

`.github/workflows/ci-cd.yml` runs on every push/PR to `main`: build → CodeQL (SAST) →
dependency/secret scan → policy gate (`az deployment sub what-if` against the Azure Policy
guardrails in `infra/`) → apply infra (`az deployment sub create`) → deploy app code → OWASP ZAP
baseline scan (DAST). Only `infra-deploy`, `deploy`, and `dast` are restricted to push on `main`
— the four checks before them also run on pull requests.

It authenticates to Azure via **OIDC federated credentials** — no client secret stored in
GitHub. Before the pipeline can do anything against Azure, add these repo secrets (Settings →
Secrets and variables → Actions):

| Secret | Value |
|---|---|
| `AZURE_CLIENT_ID` | Application (client) ID of the App Registration used by the pipeline |
| `AZURE_TENANT_ID` | `kadiz1divisionhotmail.onmicrosoft.com` tenant ID |
| `AZURE_SUBSCRIPTION_ID` | The `Udemy_Demo` subscription ID |

**The permission/trust setup is more involved than it looks**, and cost real debugging time to
get right — worth documenting precisely rather than the simplified version this section used to
have:

*Federated credentials* (Azure trusts a GitHub OIDC token as this identity, no password) — GitHub
includes immutable numeric IDs in the token's subject claim, and the subject shape also differs
for jobs tagged with a GitHub Environment, so **two** are needed on the App Registration for this
repo to fully work: one for a plain push to `main`
(`repo:<owner>@<owner-id>/<repo>@<repo-id>:ref:refs/heads/main`), and one for jobs tagged
`environment: production` (`repo:<owner>@<owner-id>/<repo>@<repo-id>:environment:production` —
both `infra-deploy` and `deploy` use that environment). Get the exact numeric IDs from a failed
run's error message (`AADSTS700213: No matching federated identity record...` includes the exact
subject GitHub actually sent) rather than guessing them — don't use the plain `repo:<owner>/<repo>`
form some older docs/examples show, it won't match.

*Azure role assignments* — `Contributor` scoped to `rg-jmalabuk-dev-wcus` covers most resource
management, but **is not enough** for the `policy-gate`/`infra-deploy` jobs, because Azure
deliberately excludes `Microsoft.Authorization/*` actions (policy assignments, role assignments)
from `Contributor` — even a dry-run `what-if` needs the real write permission to simulate those.
The identity ends up needing four grants total:
- `Contributor` on `rg-jmalabuk-dev-wcus`
- A custom role (`Microsoft.Resources/deployments/*` only) on the **subscription**, since
  `main.bicep`'s `targetScope` is `subscription` (it creates the resource group itself)
- `Resource Policy Contributor` on `rg-jmalabuk-dev-wcus` (for the Azure Policy assignments in
  `infra/modules/policy.bicep`)
- `User Access Administrator` on `rg-jmalabuk-dev-wcus` (for the Key Vault RBAC role assignment
  in `infra/modules/appservice.bicep`) — this one is categorically different from the others,
  it's IAM-granting power, not resource management, even though it's scoped to one small RG.
  Worth knowing before granting it.

None of this is set up automatically, and it's easy to under-grant on a first attempt — if
rebuilding this from scratch, expect to re-derive some of it from a failed run's error text; the
errors are specific enough to point at the exact missing grant each time.

**Not yet configured**: GitHub Environment required-reviewer approval on `production` — right now
`infra-deploy` and `deploy` run fully unattended on every push to `main`, no human clicks approve
first. Would be the natural next step before this pattern is "production-real" rather than
lab-real.

## Deploying app code changes manually (bypassing the pipeline)

There are two *separate* deployments in this repo, and it's easy to mix them up:

1. **Infrastructure** (`az deployment sub create`, above) — creates the empty App Service,
   Key Vault, VNet, etc. It does **not** put your code on the App Service. Normally the
   pipeline's `infra-deploy` job re-runs this automatically on every push to `main`; the manual
   command is only needed for the first-ever bootstrap or if the pipeline itself is broken.
2. **App code** — the actual `SimpleApp` C# code. Normally this happens automatically via
   `.github/workflows/ci-cd.yml` on push to `main`. If you need to push a change without
   waiting on the pipeline (e.g. the pipeline itself is broken), here's the manual equivalent,
   run from `app/SimpleApp`:

   ```pwsh
   # Build the app into a folder called publish/
   dotnet publish -c Release -o ./publish

   # Zip that folder up
   Compress-Archive -Path .\publish\* -DestinationPath .\deploy.zip -Force

   # Push the zip to the already-deployed App Service
   az webapp deploy --resource-group rg-jmalabuk-dev-wcus --name app-jmalabuk-simpleapp --src-path .\deploy.zip --type zip
   ```

   `publish/`, `bin/`, `obj/`, and `*.zip` are build output, regenerated every time — they're
   git-ignored on purpose and never need to be committed or manually cleaned up.

3. **Verify**:
   ```
       curl https://app-jmalabuk-simpleapp.azurewebsites.net/healthz
       curl https://app-jmalabuk-simpleapp.azurewebsites.net/config/status
   ```
   
See `docs/ARCHITECTURE.md` for the full diagram and the reasoning behind each control.
