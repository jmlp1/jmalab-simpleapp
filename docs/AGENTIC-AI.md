# Agentic AI in this workflow

The brief asks for "hands-on use of agentic AI tooling... and a clear point of view on how to
apply it well and safely." This lab treats agentic AI as a workflow participant with defined
inputs, outputs, and a human checkpoint — not a black box that ships changes unsupervised.

## Where it's used here

| Task | How agentic AI helps | Human checkpoint |
|---|---|---|
| **Policy authoring** | Drafting new Azure Policy JSON (like `policies/azure-policy-definitions/*.json`) from a plain-English control requirement, and generating the Bicep to assign it | Policy JSON is reviewed and merged via normal PR process — same branch protection as app code |
| **Change-impact analysis** | Given a PR diff against `infra/`, summarising what Azure resources change, which policies it might trip, and which teams' workloads it could affect | Summary is posted as a PR comment for the human reviewer, not auto-applied |
| **SARIF triage** | Given a batch of CodeQL/ZAP findings, clustering duplicates and suggesting which are false positives vs. real, with reasoning | A human still sets the "waived" label — agentic output is a triage aid, not the gate itself |
| **IaC scaffolding** | Generating new Bicep modules for a new golden-path resource type from a short spec (as this lab itself was partly built) | New modules go through the same policy-preflight + CodeQL pipeline as everything else — AI-authored code gets zero special trust |

## The guardrails that make this safe to run in an engineering workflow

1. **No write access to production from the agent.** Agentic tooling operates on branches/PRs.
   The only thing with deploy credentials is the pipeline's OIDC-federated identity, scoped to
   `Contributor` on one resource group.
2. **Everything the agent touches goes through the same gates as human-authored change** — CodeQL,
   dependency review, policy what-if. There's no "AI fast lane."
3. **Prompts and generated artefacts are logged alongside the PR** they relate to, so a reviewer
   (or an auditor) can see what was asked for and what was produced — this is the same "evidence
   as a by-product" principle applied to AI usage itself.
4. **Scope discipline** — agentic tooling is used for narrow, well-specified tasks (policy
   authoring, triage, summarisation) rather than open-ended "manage the platform" autonomy. The
   point of view here is that agentic AI is currently most trustworthy as a fast first-drafter
   and pattern-matcher, with a human owning judgement calls that carry real risk (what to waive,
   what to merge, what to deploy).

## What this deliberately avoids

- Auto-merging AI-authored infra changes.
- Letting an agent hold or rotate its own Azure credentials.
- Using AI output as the sole evidence for an audit finding — AI-assisted triage still needs a
  named human sign-off, which is what actually satisfies assurance.
