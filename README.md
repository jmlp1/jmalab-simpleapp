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
| `app/SimpleApp` | Minimal .NET 8 API — the "product team" workload the platform hosts | Proof the golden path actually runs a real app |
| `.github/workflows` | CI/CD: build → SAST (CodeQL) → dependency/secret scanning → policy gate → deploy → DAST (OWASP ZAP) | "Embed SAST/DAST into CI/CD... enforce as policy gates" |
| `policies/` | Azure Policy-as-code definitions (deny-by-default guardrails) | "Guardrails as code... compliant by construction" |
| `docs/ARCHITECTURE.md` | System diagram + design rationale | "Represent posture to Security and audit" |
| `docs/DOMAIN-SETUP.md` | Binding `jmalab.uk` + TLS cert to the App Service | Custom domain / cert handling |
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
| GitHub | Free plan (public repo) or free private-repo Actions minutes | CodeQL is free on public repos; free minutes cover this on private too |

> ⚠️ Nothing here needs a paid Azure tier. If you later add Azure Front Door, WAF, or a paid App
> Service plan for staging slots, flag it — those are the first things that would burn credits.

## Quick start

```bash
# 1. Deploy the landing zone
az deployment sub create \
  --location uksouth \
  --template-file infra/main.bicep \
  --parameters infra/parameters/dev.bicepparam

# 2. Push app/ and .github/ to a new GitHub repo — the workflow deploys on push to main
git init && git remote add origin https://github.com/<you>/jmalab-simpleapp.git

# 3. Bind the custom domain — see docs/DOMAIN-SETUP.md
```

See `docs/ARCHITECTURE.md` for the full diagram and the reasoning behind each control.
