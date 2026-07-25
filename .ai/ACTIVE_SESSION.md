# ACTIVE SESSION - read me first

Last updated: 2026-07-22 (after full teardown)

## 🚨 Live infrastructure & money meter

**NOTHING IS DEPLOYED. Cost meter ≈ $0.**

Full `terragrunt run --all -- destroy` of live/dev completed 2026-07-22:
72 resources across 4 units (wus3/eus2 × hub/aks-spoke), zero errors.
Reverse dependency order held (spokes → eus2 hub → wus3 hub).

Still existing, on purpose:
- `rg-tfstate-dev` + state storage account (names in `.env`) - holds all
  terraform state; costs pennies; enables identical rebuild.
- prod/ tree: defined, never applied (by design).

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

## Immediate next steps

See .ai/status/task-backlog.md. Top of stack:
1. Set the 5 GitHub repo variables to activate plan.yml (docs/github-oidc-setup.md).
2. Verify ci.yml is green on GitHub.
