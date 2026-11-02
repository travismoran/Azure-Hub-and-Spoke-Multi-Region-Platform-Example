# ACTIVE SESSION - read me first

Last updated: 2026-11-02 (DEV IS UP with the AVNM mesh - ~$150/mo accruing)

## 🚨 Live infrastructure & money meter

**Cost meter ≈ $150/mo while dev stays up** (2× D2s_v6 nodes, 2 AVNM
managed VNets, 2 ACR Basic, 2 LB IPs). Deployed 2026-11-02:
- `live/platform`: mg-demo tree; in connectivity: `rg-avnm-platform` /
  `avnm-platform` (scope mg-demo), 6 IPAM pools (2 roots, dev+prod per
  region), dev+prod network groups/meshes/rule collections, 4 commits.
- `live/dev` (both regions): hubs in connectivity (no firewall), stamps
  in the dev subscription: VNets 10.16.0.0/22 + 10.32.0.0/22 from IPAM,
  AKS `aks-demo-dev-{wus3,eus2}` (Cilium dataplane), ACR Basic. Mesh +
  caller-identity policy + rule 300 all verified
  (.ai/test-results/2026-11-02-avnm-mesh-e2e.md). Test namespaces deleted.
- TEMP edits still in `live/dev/env.hcl`: `enable_avnm = true`,
  `network_policy = "cilium"` - decide defaults before merging PR #1.
Tear down dev: `cd live/dev && terragrunt run --all -- destroy` (platform
stays, $0). Kubeconfigs: `~/.kube/aks-demo-dev-{wus3,eus2}.yaml`.

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
1. Decide: destroy dev now (saves ~$150/mo) or keep for the N-stamp demo;
   decide dev defaults for `enable_avnm` / `network_policy` (TEMP edits).
2. Merge PR #1 (CI green; all verification done).
3. Optional: drop Owner at `/` back to Management Group Contributor.
4. GitHub repo variables for plan.yml (now incl. TG_SUBSCRIPTION_*).
