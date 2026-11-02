# ACTIVE SESSION - read me first

Last updated: 2026-11-02 (live/platform applied incl. prod placement; environments not applied)

## 🚨 Live infrastructure & money meter

**Cost meter ≈ $0.** Deployed (2026-11-02, from `live/platform`): the
management-group tree `mg-demo/*` and, in the connectivity subscription,
`rg-avnm-platform` with `avnm-platform` (scope mg-demo), 4 IPAM pools,
prod network group/mesh/rules, 4 commits. All free until a VNet is
managed. No hubs, no clusters, no stamp VNets.

Full `terragrunt run --all -- destroy` of live/dev completed 2026-07-22:
72 resources across 4 units (wus3/eus2 × hub/aks-spoke), zero errors.
Reverse dependency order held (spokes → eus2 hub → wus3 hub).

Still existing, on purpose:
- `rg-tfstate-dev` + state storage account (names in `.env`) - holds all
  terraform state; costs pennies; enables identical rebuild. Lives in the
  original "Pay-As-You-Go" subscription = the **management** subscription.
- prod/ tree: defined, never applied (by design).

Subscriptions in the tenant (IDs only in `.env`, never here):
`Pay-As-You-Go` (management: state), `connectivity`, `dev`, `prod` - the
last three created in the portal 2026-11-01/02 (billing account is MOSP →
no API vending), providers registered via bootstrap/register-providers.sh,
all placed in the mg-demo tree by Terraform. User holds Owner + User
Access Administrator at `/` (elevated 2026-11-02; can be trimmed).

Stale local artifacts: `~/.kube/aks-demo-dev-{wus3,eus2}.yaml` point at
deleted clusters - regenerate with `az aks get-credentials --file ...` after
any re-apply.

## Rebuild from zero (verified workflow)

```bash
source .env && az login    # subscription context
cd live/dev/westus3 && terragrunt run --all -- apply   # ~10 min, ~$100/mo
cd ../eastus2      && terragrunt run --all -- apply   # ~25 min with firewalls
```
`enable_firewall` is back to `false` (2026-07-25), so a re-apply lands at
the ~$75-100/mo/region floor with isolated regions. Flip it true to restore
the verified cross-region transit path (~+$300/mo/region). State storage +
provider registrations already in place. Note: the eus2 hub leaf still
declares the hub↔hub peering inputs - inert and free without firewalls.

## What this project has proven end-to-end

- Full platform build + teardown cycle with external state (this file's
  history: applied 2026-07-21, destroyed 2026-07-22, zero orphans).
- Cross-region cluster-to-cluster via hub firewalls transit -
  evidence preserved in .ai/test-results/2026-07-21-aks-e2e.md.

## Local machine context (WSL2)

- `source .env` before any terragrunt command (holds all real IDs/names).
- Tools in `~/.local/bin`: terraform 1.15.8, terragrunt 1.1.1, az (pip venv),
  kubelogin, gitleaks 8.24.3.
- Security tooling: `./scripts/setup-dev.sh` - already run on this machine.

## In flight: plans 003 + 004 (branch feat/avnm-ipam-mesh)

003: AVNM + IPAM + global mesh "stamp" model (ADR-010/011). 004: the
enterprise layout on top (ADR-012) - `live/platform/{management-groups,
network}` applied once per tenant, hubs + AVNM in the connectivity
subscription, stamps in `TG_SUBSCRIPTION_<ENV>`, placement in
`live/root.hcl`. Apply order: `live/platform` → `live/dev`. Everything
validates offline (10 units); nothing applied yet. Address plan renumbered
(docs/ipam.md): hubs 10.0/10.1.x, stamp roots 10.16/10.32.0.0/12.

## Immediate next steps

See .ai/status/task-backlog.md. Top of stack:
1. Live-verify plan 003 in dev with `enable_avnm = true` (~$150/mo while
   up): `cd live/dev && terragrunt run --all -- apply` (hubs → stamps,
   cross-subscription peering); record evidence; then merge PR #1.
2. Optional: drop Owner at `/` back to Management Group Contributor
   (docs/subscriptions.md).
3. GitHub repo variables for plan.yml (now incl. TG_SUBSCRIPTION_*).
