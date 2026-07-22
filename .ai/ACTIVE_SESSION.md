# ACTIVE SESSION - read me first

Last updated: 2026-07-21 (end of initial build + transit demo session)

## 🚨 Live infrastructure & money meter

`live/dev` is APPLIED in both regions and **accruing ~$1.10/hour (~$800/mo)**:

| What | Where | Cost driver |
|---|---|---|
| AKS `aks-demo-dev-wus3` (Free tier, 1× B2ms) | rg-aks-dev-wus3 | ~$60/mo |
| AKS `aks-demo-dev-eus2` (Free tier, 1× B2ms) | rg-aks-dev-eus2 | ~$60/mo |
| **Azure Firewall Basic × 2** (transit demo) | rg-hub-dev-{wus3,eus2} | **~$300/mo each** |
| 2× ACR Basic, 2× LBs/PIPs, state storage | various | ~$25/mo |

Cost levers, cheapest first:
1. `az aks stop -g rg-aks-dev-<r> -n aks-demo-dev-<r>` - pauses node compute only.
2. Kill the firewalls: set `enable_firewall = false` in `live/dev/env.hcl`,
   then `cd live/dev && terragrunt run --all -- apply` (UDRs/peering-routes
   deactivate automatically; hub-hub peering + transit test stop working).
3. Full teardown: `terragrunt run --all -- destroy` per region dir. State is
   external; re-apply rebuilds identically.

prod/ is defined but has NEVER been applied (by design - plan-only).

## Current state

- Repo: github.com/travismoran/Azure-Hub-and-Spoke-Multi-Region-Platform-Example (main, pushed)
- Hub-to-hub transit **verified end-to-end** today: curl from wus3 pod →
  eus2 internal LB (10.21.0.5) through FW1 10.10.0.4 → FW2 10.20.0.4.
  Evidence: .ai/test-results/2026-07-21-aks-e2e.md
- Test workload `hello-eus2` (nginx + internal LB) still deployed in the
  eus2 cluster's default namespace.
- All RBAC is terraform-managed: cluster-admin (via TG_CLUSTER_ADMIN_OBJECT_ID),
  kubelet AcrPull, control-plane Network Contributor on spoke vnet + route table.

## Local machine context (WSL2)

- `source .env` before anything (holds all real IDs/names - never commit).
- Kubeconfigs: `~/.kube/aks-demo-dev-wus3.yaml`, `~/.kube/aks-demo-dev-eus2.yaml`
  (kubelogin azurecli mode). `~/.kube/config` is a Rancher symlink - don't touch.
- Tools in `~/.local/bin`: terraform 1.15.8, terragrunt 1.1.1, az (pip venv at
  `~/.local/share/azure-cli-venv`), kubelogin, gitleaks.
- Security tooling: `./scripts/setup-dev.sh` (gitleaks install + hook
  activation) - already run on this machine.

## Immediate next steps

See .ai/status/task-backlog.md for the full queue. Top of stack:
1. Decide: keep firewalls running or flip `enable_firewall=false` until next demo.
2. Set the 5 GitHub repo variables to activate plan.yml (docs/github-oidc-setup.md).
3. Replace `git clone <this repo>` placeholder in README with the real URL.
