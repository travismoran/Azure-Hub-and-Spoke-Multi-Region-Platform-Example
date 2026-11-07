# ACTIVE SESSION - read me first

Last updated: 2026-11-07 (EVERYTHING from plans 003/004 destroyed - nothing deployed)

## 🚨 Live infrastructure & money meter

**Cost meter = $0/mo. Nothing is deployed.** `live/dev` was destroyed
2026-11-02 (46 resources) and `live/platform` on 2026-11-07 (29 AVNM/IPAM/
policy resources + 6 management groups), both with zero errors and zero
orphans - .ai/test-results/2026-11-02-dev-teardown.md and
.ai/test-results/2026-11-07-platform-teardown.md. All four subscriptions
sit directly under the Tenant Root Group again; no network manager, IPAM
pool, network group or AVNM policy exists anywhere in the tenant. The
platform state blobs are empty, so a fresh `live/platform` apply rebuilds
the same tree (the user still holds Owner + User Access Administrator at
`/`, so no re-elevation needed until those are removed).

Dev defaults in `live/dev/env.hcl` still carry the TEMP markers
(`enable_avnm = true`, `network_policy = "cilium"`) - a re-apply of
platform + dev lands at ~$150/mo with the mesh; revert both for the
~$75-100/mo no-AVNM floor.

Still existing, on purpose:
- `rg-tfstate-dev` + state storage account (names in `.env`) - holds all
  terraform state; costs pennies; enables identical rebuild. Lives in the
  original "Pay-As-You-Go" subscription = the **management** subscription.
- prod/ tree: defined, never applied (by design).

Subscriptions in the tenant (IDs only in `.env`, never here):
`Pay-As-You-Go` (management: state), `connectivity`, `dev`, `prod` - the
last three created in the portal 2026-11-01/02 (billing account is MOSP →
no API vending), providers registered via bootstrap/register-providers.sh,
not in any custom management group since the 2026-11-07 teardown. User
still holds Owner + User Access Administrator at `/` (elevated 2026-11-02;
remove with `az role assignment delete --scope / --assignee <object-id>
--role Owner` / `... --role "User Access Administrator"` when done).

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

- Full platform build + teardown cycle with external state, twice: applied
  2026-07-21 / destroyed 2026-07-22, and (multi-subscription, AVNM mesh)
  applied 2026-11-02 / destroyed 2026-11-02 (dev) + 2026-11-07 (platform
  incl. management groups) - zero orphans every time.
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
validates offline (10 units); applied, verified and destroyed. Address plan renumbered
(docs/ipam.md): hubs 10.0/10.1.x, stamp roots 10.16/10.32.0.0/12.

## Immediate next steps

See .ai/status/task-backlog.md. Top of stack:
1. Decide dev defaults for `enable_avnm` / `network_policy` (TEMP edits in
   live/dev/env.hcl, now on main). Everything is destroyed.
2. Optional: remove Owner + User Access Administrator at `/` (manual, see
   above); optionally cancel the connectivity/dev/prod subscriptions in the
   portal if the layout will not be rebuilt.
3. GitHub repo variables for plan.yml (now incl. TG_SUBSCRIPTION_*).

PR #1 (plans 003 + 004) merged to main 2026-11-02 (merge commit b9796dd);
branch feat/avnm-ipam-mesh deleted.
