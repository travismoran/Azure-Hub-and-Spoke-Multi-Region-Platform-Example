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

- **2 environments × 2 regions** (dev/prod × westus3/eastus2), each a
  hub-spoke pair with globally non-overlapping addressing
  ([docs/ipam.md](docs/ipam.md))
- **Landing-zone layout**: one subscription per role (management,
  connectivity, dev, prod) under a small management-group hierarchy, all
  placed by `root.hcl` from env vars - and a single-subscription mode that
  needs nothing extra ([docs/subscriptions.md](docs/subscriptions.md))
- **8-line leaf configs**: all logic lives in `root.hcl`, `platform.hcl`,
  `env.hcl`, `region.hcl`, and four `_envcommon` files - adding a region is
  one folder and two CIDRs
- **Cost toggles** for firewall, ACR SKU, Log Analytics, container insights,
  Defender, Azure Policy, cluster tier, private cluster
  ([docs/costs.md](docs/costs.md))
- **Stamp networking, two ways**: every AKS spoke is a uniform /22 "stamp"
  with a fixed subnet layout. Turn on `enable_avnm` and one tenant-wide
  Azure Virtual Network Manager hands each stamp its /22 from a region →
  environment IPAM pool hierarchy, puts it in a tag-driven network group,
  meshes every stamp of the environment across regions and subscriptions
  (direct cluster-to-cluster, no hub hop) and applies security admin
  guardrails ([docs/network-platform.md](docs/network-platform.md))
- **Zero secrets**: `az login` / GitHub OIDC auth, Entra RBAC state access
  (no storage keys), managed identities everywhere, gitleaks in CI and
  pre-commit
- **Offline-validatable**: the whole dependency graph inits, validates, and
  plans with mocked cross-stack outputs and a local-backend fallback - CI
  needs no Azure at all for the `ci` workflow

## Layout

```
modules/
├── hub/                wraps avm-ptn-hubnetworking (firewall optional, off by default)
├── aks-spoke/          stamp vnet (/22, static or IPAM) + hub peering + AKS + optional ACR/LAW
└── platform-network/   AVNM + IPAM pools + network group + global mesh + security admin
live/
├── root.hcl                     backend + provider generation (env-var driven)
├── _envcommon/{hub,aks-spoke,platform-network}.hcl   shared unit config + dependency wiring
├── dev/                         cheapest-possible settings
│   ├── env.hcl
│   ├── platform-network/        one per environment (empty when enable_avnm = false)
│   ├── westus3/{region.hcl, hub/, aks-spoke/}
│   └── eastus2/{region.hcl, hub/, aks-spoke/}
└── prod/                        every toggle on (plan-only demonstration)
bootstrap/        az CLI script that creates the state storage account
docs/             architecture, subscriptions, IPAM, network platform, costs, OIDC setup
```

## Quick start

Prereqs: [terraform](https://developer.hashicorp.com/terraform/install) and
[terragrunt](https://terragrunt.gruntwork.io/) (versions in
`.tool-versions`), the [az CLI](https://learn.microsoft.com/cli/azure/), and
an Azure subscription - or several, one per role, for the landing-zone
layout ([docs/subscriptions.md](docs/subscriptions.md)).

```bash
git clone git@github.com:travismoran/Azure-Hub-and-Spoke-Multi-Region-Platform-Example.git
cd Azure-Hub-and-Spoke-Multi-Region-Platform-Example

# 0. One-time: install pinned gitleaks + activate secret-scan git hooks
./scripts/setup-dev.sh

# 1. Configure your environment (nothing real is ever committed)
cp .env.example .env    # edit: subscription(s), tenant, state names, your IP
source .env
az login

# 2. One-time: create the remote state storage account
./bootstrap/bootstrap-state.sh

# 3. One-time: register resource providers in every subscription
#    (the provider config sets resource_provider_registrations = "none")
./bootstrap/register-providers.sh

# 4. One-time, multi-subscription layout only: tenant-root access for the
#    management groups (docs/subscriptions.md), then the tenant-level platform
cd live/platform && terragrunt run --all -- apply     # management groups → network platform

# 5. Plan and apply dev (hubs → spokes via the dependency graph)
cd ../dev
terragrunt run --all -- plan
terragrunt run --all -- apply
#    One region only: cd live/dev/westus3 && terragrunt run --all -- apply

# 6. Connect
az aks get-credentials -g rg-aks-dev-wus3 -n aks-demo-dev-wus3
kubectl get nodes
```

Tear down with `terragrunt run --all -- destroy` in the same directory.
(`live/platform/network` is an external dependency of every spoke; its
outputs are read from state, so apply the platform first. Validation works
from anywhere because the dependency is mocked.)

No subscription yet? Everything still validates offline:

```bash
cd live && terragrunt run --all -- validate
```

## Feature toggles

Set per environment in `live/<env>/env.hcl`:

| Toggle | dev | prod | Cost impact |
|---|---|---|---|
| `aks_sku_tier` | `Free` | `Standard` | $73/mo/cluster |
| `enable_firewall` | `false`* | `true` | $300-900+/mo |
| `enable_avnm` | `false`** | `true` | ~$73/mo per stamp VNet + IPAM per IP (the AVNM itself is free) |
| `private_cluster_enabled` | `false` | `true` | needs jumpbox/Bastion to reach |
| `acr_sku` | `Basic` | `Premium` | $5 vs $50/mo |
| `enable_log_analytics` | `false` | `true` | ~$2.76/GB ingested |
| `enable_container_insights` | `false` | `true` | ingestion volume |
| `enable_defender` | `false` | `true` | ~$7/vCPU/mo |
| `enable_azure_policy` | `false` | `true` | free |
| `enable_telemetry` (AVM) | `false` | `false` | phone-home, disabled |
| system pool | 1× B2s_v2 | 3× D4ds_v5 zoned | ~10× |
| user pools | Spot, scales from 0 | on-demand zoned | ~5-10× |

\* flip to `true` to enable the cross-region hub-to-hub transit path
(Firewall Basic per hub, UDRs, transit rules - all activate automatically;
see [docs/architecture.md](docs/architecture.md)). Verified end-to-end;
evidence in `.ai/test-results/`.

\** flip to `true` to opt the environment into the tenant-wide AVNM
(`live/platform/network`): IPAM-allocated stamp /22s, one global mesh per
environment (direct cross-region cluster-to-cluster with no firewall in the
path) and security admin guardrails; see
[docs/network-platform.md](docs/network-platform.md). Not yet verified live.

## CI

- **`ci.yml`** - runs on every push/PR with no configuration: gitleaks secret
  scan, `terraform fmt`, `terragrunt hcl fmt`/`validate`, module validation,
  and a full offline `run --all validate` of the live tree.
- **`plan.yml`** - optional: `terragrunt run --all plan` for dev against your
  real subscription(s) via OIDC federated credentials
  ([docs/github-oidc-setup.md](docs/github-oidc-setup.md)). Skips itself if
  the repo variables aren't set. **There is deliberately no apply job.**

## Deliberate omissions

- **No secrets, anywhere** - and no values that even look like them. Layered
  enforcement: `scripts/setup-dev.sh` installs pinned gitleaks and activates
  git hooks (pre-commit: file types + keyword patterns + gitleaks staged;
  pre-push: worktree + full history), with the same checks in
  `.pre-commit-config.yaml` and CI as backstops.
- **No applies in CI** - this is an example; applying costs money and should
  be a human decision.
- **No Terragrunt stacks** - the experimental `terragrunt.stack.hcl` feature
  could shrink the leaf files further, but classic includes are stable and
  universally understood.
- **No subscription vending** - subscriptions are created in the portal and
  referenced by ID; Terraform-created subscriptions need an EA/MCA/MPA
  billing account, which a personal Pay-As-You-Go account is not
  ([docs/subscriptions.md](docs/subscriptions.md)).
- **Forks must change `TG_NAME_PREFIX`** (or `name_prefix` default) - ACR
  and storage account names are globally unique across Azure, and
  management group IDs are unique per tenant.

## License

MIT - see [LICENSE](LICENSE).
