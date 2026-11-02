# azure-aks-platform - project guidelines

Public example repo: DRY Terraform + Terragrunt AKS platform, hub-and-spoke,
dev/prod × westus3/eastus2, cost-minimized defaults. AVM modules composed
directly (NOT avm-ptn-aks-enterprise - see .ai/status/decisions-adr.md).
Spokes are uniform /22 "stamps"; `enable_avnm` opts an environment into the
tenant-wide AVNM + IPAM + global mesh (`modules/platform-network`,
docs/network-platform.md). Landing-zone layout: subscriptions per role
(management/connectivity/dev/prod) under management groups, placed by
`live/root.hcl` from `TG_SUBSCRIPTION_*` env vars (docs/subscriptions.md).

## Session pickup

**Always read `.ai/ACTIVE_SESSION.md` first** - it holds live infrastructure
state, costs currently accruing, kubeconfig paths, and next steps.
Plans in `.ai/plans/`, test evidence in `.ai/test-results/`, backlog and
ADRs in `.ai/status/`. Keep all of these updated as work progresses.

## Hard rules

1. **No secrets in the repo - ever.** See `.claude/rules/no-secrets.md`.
   Anything account-specific comes from env vars (`.env`, gitignored).
2. Every expensive Azure feature must be a toggle in `env.hcl`, and new
   toggles default to the cheapest setting.
3. AVM module versions are pinned exactly (pre-1.0 semver - no `~>`).
4. Leaf `terragrunt.hcl` files stay minimal; logic belongs in `root.hcl`,
   `env.hcl`, `region.hcl`, or `_envcommon/`.
5. Never write to `~/.kube/config` (it's a Rancher Desktop symlink); use
   `az aks get-credentials --file ~/.kube/<cluster>.yaml` + kubelogin.

## Dev commands

```bash
source .env                                   # required before any tg command
cd live/platform && terragrunt run --all -- apply        # once per tenant: MGs → AVNM ($0)
cd live/dev && terragrunt run --all -- plan              # plan an environment
terragrunt run --all -- apply -input=false               # apply (hub → spoke)
cd live/dev/<region> && terragrunt run --all -- apply    # one region (platform outputs read from state)
cd live && terragrunt run --all -- validate              # offline full-graph check
terraform fmt -recursive && terragrunt hcl fmt           # format
bash githooks/pre-push                                   # manual secret sweep
```

One-time per clone: `./scripts/setup-dev.sh` - installs gitleaks (pinned,
checksum-verified) and activates the secret-scan git hooks.
Offline validation needs no Azure: unset `TG_STATE_*` and root.hcl falls back
to a local backend; hub outputs are mocked.

## Environment quirks

- Terragrunt 1.x CLI: `run --all -- <cmd>`, `hcl fmt`, `hcl validate`.
- Tools live in `~/.local/bin` (terraform 1.15.8, terragrunt 1.1.1, az via
  pip venv, gitleaks, kubelogin).
- azurerm 4.x: no default subscription; `live/root.hcl` sets it per unit
  from `TG_SUBSCRIPTION_*` (fallback `ARM_SUBSCRIPTION_ID`); provider sets
  `resource_provider_registrations = "none"` → run
  bootstrap/register-providers.sh for every new subscription.
- Management groups need tenant-root elevation once (docs/subscriptions.md);
  the billing account is MOSP, so subscriptions are portal-created, never
  vended by Terraform.
- If terragrunt errors "Backend initialization required" after switching
  between offline/real modes, delete the unit's `.terragrunt-cache`.
- AVM quirks (hubnetworking null-derefs, BYO-VNet RBAC needs) are documented
  in .ai/status/decisions-adr.md - read before touching modules/.
