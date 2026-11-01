# ACTIVE SESSION - read me first

Last updated: 2026-11-01 (plans 003 + 004 implemented offline, not applied)

## 🚨 Live infrastructure & money meter

**NOTHING IS DEPLOYED. Cost meter ≈ $0.**

Full `terragrunt run --all -- destroy` of live/dev completed 2026-07-22:
72 resources across 4 units (wus3/eus2 × hub/aks-spoke), zero errors.
Reverse dependency order held (spokes → eus2 hub → wus3 hub).

Still existing, on purpose:
- `rg-tfstate-dev` + state storage account (names in `.env`) - holds all
  terraform state; costs pennies; enables identical rebuild. Lives in the
  original "Pay-As-You-Go" subscription = the **management** subscription.
- prod/ tree: defined, never applied (by design).

Subscriptions in the tenant (2026-11-01; IDs only in `.env`, never here):
`Pay-As-You-Go` (management: state), `connectivity`, `dev` - both new,
created in the portal (billing account is MOSP → no API vending), resource
providers registered via bootstrap/register-providers.sh. `prod`: blocked
by the 24h subscription-creation rate limit, create tomorrow. No
management groups exist yet (needs tenant-root elevation, user action).

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
1. User: tenant-root elevation (docs/subscriptions.md step 4) + fill
   `TG_SUBSCRIPTION_MANAGEMENT/CONNECTIVITY/DEV` in .env, `PROD=""`.
2. `cd live/platform && terragrunt run --all -- plan` then apply ($0:
   MGs + AVNM + empty prod pools). Verify in portal / `az account
   management-group show -n mg-demo -e -r`.
3. Tomorrow: prod subscription → `TG_SUBSCRIPTION_PROD` → register
   providers → re-apply management-groups.
4. Live-verify plan 003 in dev with `enable_avnm = true` (~$150/mo while
   up); record evidence; merge to main.
5. GitHub repo variables for plan.yml (now incl. TG_SUBSCRIPTION_*).
