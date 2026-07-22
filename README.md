# azure-aks-platform

A public example of a **DRY, multi-environment, multi-region Azure AKS
platform** built with Terraform + Terragrunt on a **hub-and-spoke** network
topology - composed from [Azure Verified Modules](https://aka.ms/avm) and
tuned so the development configuration costs **~$75-100/month**, not
$1,700+.

Inspired by
[`Azure/terraform-azurerm-avm-ptn-aks-enterprise`](https://github.com/Azure/terraform-azurerm-avm-ptn-aks-enterprise),
but not consuming it: at v0.1.0 that pattern hardcodes an Azure Firewall
Standard, ACR Premium, a private cluster with UDR, and D16ds_v5 nodes, and it
can't join an existing hub-spoke topology (it creates its own VNet and
doesn't export its ID). This repo composes the same AVM building blocks
directly and puts **every expensive feature behind a per-environment
toggle, defaulting to off**. Details in
[docs/architecture.md](docs/architecture.md).

## What you get

- **2 environments × 2 regions** (dev/prod × westus3/eastus2), each an
  independent hub-spoke pair with globally non-overlapping addressing
  ([docs/ipam.md](docs/ipam.md))
- **8-line leaf configs**: all logic lives in `root.hcl`, `env.hcl`,
  `region.hcl`, and two `_envcommon` files - adding a region is one folder
  and four CIDRs
- **Cost toggles** for firewall, ACR SKU, Log Analytics, container insights,
  Defender, Azure Policy, cluster tier, private cluster
  ([docs/costs.md](docs/costs.md))
- **Zero secrets**: `az login` / GitHub OIDC auth, Entra RBAC state access
  (no storage keys), managed identities everywhere, gitleaks in CI and
  pre-commit
- **Offline-validatable**: the whole dependency graph inits, validates, and
  plans with mocked cross-stack outputs and a local-backend fallback - CI
  needs no Azure at all for the `ci` workflow

## Layout

```
modules/
├── hub/          wraps avm-ptn-hubnetworking (firewall optional, off by default)
└── aks-spoke/    spoke vnet + hub peering + AKS + optional ACR/Log Analytics
live/
├── root.hcl                     backend + provider generation (env-var driven)
├── _envcommon/{hub,aks-spoke}.hcl   shared unit config + dependency wiring
├── dev/                         cheapest-possible settings
│   ├── env.hcl
│   ├── westus3/{region.hcl, hub/, aks-spoke/}
│   └── eastus2/{region.hcl, hub/, aks-spoke/}
└── prod/                        every toggle on (plan-only demonstration)
bootstrap/        az CLI script that creates the state storage account
docs/             architecture, IPAM, costs, OIDC setup
```

## Quick start

Prereqs: [terraform](https://developer.hashicorp.com/terraform/install) and
[terragrunt](https://terragrunt.gruntwork.io/) (versions in
`.tool-versions`), the [az CLI](https://learn.microsoft.com/cli/azure/), and
an Azure subscription.

```bash
git clone <this repo> && cd azure-aks-platform

# 1. Configure your environment (nothing real is ever committed)
cp .env.example .env    # edit: subscription, tenant, state names, your IP
source .env
az login

# 2. One-time: create the remote state storage account
./bootstrap/bootstrap-state.sh

# 3. One-time per subscription: register resource providers
#    (the provider config sets resource_provider_registrations = "none")
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.ContainerRegistry
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.OperationalInsights

# 4. Plan and apply one region of dev (hub first via the dependency graph)
cd live/dev/westus3
terragrunt run --all -- plan
terragrunt run --all -- apply

# 5. Connect
az aks get-credentials -g rg-aks-dev-wus3 -n aks-demo-dev-wus3
kubectl get nodes
```

Tear down with `terragrunt run --all -- destroy` in the same directory.

No subscription yet? Everything still validates offline:

```bash
cd live && terragrunt run --all -- validate
```

## Feature toggles

Set per environment in `live/<env>/env.hcl`:

| Toggle | dev | prod | Cost impact |
|---|---|---|---|
| `aks_sku_tier` | `Free` | `Standard` | $73/mo/cluster |
| `enable_firewall` | `false` | `true` | $300-900+/mo |
| `private_cluster_enabled` | `false` | `true` | needs jumpbox/Bastion to reach |
| `acr_sku` | `Basic` | `Premium` | $5 vs $50/mo |
| `enable_log_analytics` | `false` | `true` | ~$2.76/GB ingested |
| `enable_container_insights` | `false` | `true` | ingestion volume |
| `enable_defender` | `false` | `true` | ~$7/vCPU/mo |
| `enable_azure_policy` | `false` | `true` | free |
| `enable_telemetry` (AVM) | `false` | `false` | phone-home, disabled |
| system pool | 1× B2ms | 3× D4ds_v5 zoned | ~10× |
| user pools | Spot, scales from 0 | on-demand zoned | ~5-10× |

## CI

- **`ci.yml`** - runs on every push/PR with no configuration: gitleaks secret
  scan, `terraform fmt`, `terragrunt hcl fmt`/`validate`, module validation,
  and a full offline `run --all validate` of the live tree.
- **`plan.yml`** - optional: `terragrunt run --all plan` for dev against your
  real subscription via OIDC federated credentials
  ([docs/github-oidc-setup.md](docs/github-oidc-setup.md)). Skips itself if
  the repo variables aren't set. **There is deliberately no apply job.**

## Deliberate omissions

- **No secrets, anywhere** - and no values that even look like them; CI runs
  gitleaks and so does the pre-commit config (`pre-commit install`).
- **No applies in CI** - this is an example; applying costs money and should
  be a human decision.
- **No Terragrunt stacks** - the experimental `terragrunt.stack.hcl` feature
  could shrink the leaf files further, but classic includes are stable and
  universally understood.
- **Forks must change `TG_NAME_PREFIX`** (or `name_prefix` default) - ACR
  and storage account names are globally unique across Azure.

## License

MIT - see [LICENSE](LICENSE).
