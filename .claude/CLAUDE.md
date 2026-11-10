# azure-aks-platform - project guidelines

Public example repo: DRY Terraform + Terragrunt AKS platform, hub-and-spoke,
dev/prod × westus3/eastus2, cost-minimized defaults. AVM modules composed
directly (NOT avm-ptn-aks-enterprise - see .ai/status/decisions-adr.md).
Spokes are uniform /22 "stamps"; `enable_avnm` opts an environment into the
tenant-wide AVNM + IPAM + global mesh (`modules/platform-network`,
docs/network-platform.md). Landing-zone layout: subscriptions per role
(management/connectivity/dev/prod) under management groups, placed by
`live/root.hcl` from `TG_SUBSCRIPTION_*` env vars (docs/subscriptions.md).
Default name prefix is `demo` (`TG_NAME_PREFIX`). Optional public DNS:
`TG_PUBLIC_DNS_PARENT_ZONE` (e.g. `azure.example.com`) → `<env>.<zone>` from
`live/platform/dns` (docs/dns.md). Optional external environment `local`
(a laptop cluster) behind `TG_ENABLE_LOCAL_CLUSTER`.

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

---

# Coding Agent Guidelines

This section outlines the required patterns, rules, and best practices for developing and maintaining Terraform and Terragrunt infrastructure in this repository. AI agents must follow these guidelines strictly when generating or modifying code.

---

## 1. Architecture & DRY Principles

- **Terragrunt DRY Hierarchy**: Standardize infrastructure configurations using Terragrunt to keep Terraform code DRY (Don't Repeat Yourself). Use `terragrunt.hcl` files for environment orchestration and variable passing.
- **Modularization First**: Encapsulate any reusable logic or infrastructure component into a standalone Terraform module under `modules/<component-name>`. Do not inline resource blocks directly into environment root units if they can be modularized.
- **Azure Verified Modules (AVM) Wrappers**:
  - Always check for an official **Azure Verified Module (AVM)** before creating a custom module for Azure resources.
  - If an AVM exists, create an internal wrapper module around it to enforce organizational defaults, mandatory tags, and naming conventions.
  - Expose only the required parameters through the wrapper's variables while supplying default parameters internally.

---

## 2. Dependency & Source Versioning (Security First)

- **Commit Hashes over Tags**: Always pin external module dependencies (including AVM modules, Git repositories, and Terraform Registry sources) to a full **40-character SHA-1 commit hash**.
  - **Forbidden**: `ref=v1.2.0`, `ref=main`, `source = "Azure/avm-res-resources-resourcegroup/azurerm?ref=v0.1.0"`
  - **Required**: `source = "git::https://github.com/Azure/terraform-azurerm-avm-res-resources-resourcegroup.git?ref=a1b2c3d4e5f678901234567890abcdef12345678"`
- **Provider Version Pinning**: Explicitly declare required provider versions using exact or pessimistic version constraints (e.g., `~> 3.0`) in a dedicated `versions.tf` file inside every module.
- **Terragrunt Source Pinning**: When pointing `terragrunt.hcl` to local or remote modules, enforce strict commit SHA refs for remote sources.

---

## 3. Recommended Infrastructure Best Practices

### A. Terraform Code Structure
Every Terraform module must follow the standard directory structure:
```text
module-name/
├── main.tf          # Primary resource definitions
├── variables.tf     # Strict variable declarations (with types & descriptions)
├── outputs.tf       # Explicit module outputs (with descriptions)
├── versions.tf      # Provider and Terraform version constraints
└── README.md        # Generated via terraform-docs
```

### B. Input Variables & Outputs
- **Type Constraints**: Define explicit types (`type = string`, `type = map(object({ ... }))`) for every variable. Avoid `type = any`.
- **Descriptions**: Every variable and output must contain a meaningful `description` field.
- **Validation Blocks**: Use custom `validation` blocks within variables to catch invalid inputs early (e.g., naming patterns, allowed CIDR ranges).
- **Sensitive Data**: Mark sensitive variables and outputs with `sensitive = true`. Never hardcode secrets, API keys, or credentials in `.tf` or `.hcl` files.

### C. Terragrunt Patterns
- Use `dependency` blocks to pass outputs between Terragrunt modules.
- Maintain global settings (remote state backends, provider configurations, global tags) in a top-level `root.hcl` (or `terragrunt.hcl`) and inherit them via `include`.
- Avoid hardcoding environment-specific values; pass them via `inputs = { ... }` in the target environment `terragrunt.hcl`.

### D. Naming Conventions & Tagging
- Follow standard resource naming conventions (e.g., `<prefix>-<environment>-<region>-<resource_type>-<name>`).
- Require a standard map of tags (e.g., `Environment`, `Owner`, `ManagedBy = "Terragrunt"`, `Repository`) passed into all module wrappers.

---

## 4. Required Formatting & Linting Workflow

Agents must execute and pass the following steps before submitting code:

1. **Formatting**:
   - `terraform fmt -recursive`
   - `terragrunt hclfmt`
2. **Validation**:
   - `terragrunt run-all validate`
3. **Security & Linting**:
   - Run `trivy` or `tfsec` to scan for security misconfigurations.
   - Run `tflint` across modified modules to detect deprecated syntax or invalid attributes.
4. **Documentation**:
   - Update `README.md` using `terraform-docs markdown table . > README.md` for modified modules.

---

## 5. Agent Enforcement Rules Summary

| Rule | Enforcement Directive |
| :--- | :--- |
| **Module Sources** | **MUST** use full 40-character commit SHAs (`?ref=<commit_hash>`). Never use tags or branch names. |
| **Azure Modules** | **MUST** wrap official AVM modules when available rather than writing resources from scratch. |
| **DRY Enforcement** | **MUST** extract repeated resource blocks into `modules/` wrappers. |
| **Variable Declarations** | **MUST** contain `type`, `description`, and appropriate `validation` or `sensitive` attributes. |
| **Format & Checks** | **MUST** run `terraform fmt` and `terragrunt hclfmt` on generated files. |

---

## 6. How the guidelines map onto this repo today (2026-11-07)

The guidelines above are the target. Where the imported code or toolchain
does not meet them yet, this is the state of play and what to do:

- **Terragrunt CLI**: this repo runs terragrunt 1.x, where `terragrunt hclfmt`
  is `terragrunt hcl fmt` and `terragrunt run-all validate` is
  `terragrunt run --all -- validate` (see Dev commands). Use the 1.x forms.
- **Module sources**: the six AVM modules are consumed from the Terraform
  Registry with exact `version = "x.y.z"` pins (hard rule 3), not git commit
  SHAs. Migrating to `git::https://github.com/Azure/terraform-azurerm-avm-*.git?ref=<sha>`
  is a backlog item; until then, any *new* external module source MUST use
  a 40-character SHA, and when touching an existing AVM pin, convert it.
  Record the tag the SHA corresponds to in a trailing comment.
- **Provider constraints**: modules use `>= 4.0, < 5.0` (azurerm) and
  `>= 2.4, < 3.0` (azapi) in `versions.tf`, which satisfies the pessimistic-
  constraint requirement; do not widen them.
- **Linting tools**: `tflint`, `trivy`/`tfsec` and `terraform-docs` are not
  installed on the dev machine or in `ci.yml` yet, and modules have no
  generated README.md. Until they are added (backlog), run every check that
  exists (`terraform validate`, offline `run --all -- validate`, gitleaks)
  and say explicitly in the summary that the lint/docs steps were skipped.
- **Naming**: existing resources follow `<type>-<prefix>-<env>-<region>`
  (e.g. `aks-demo-dev-wus3`, `rg-aks-dev-wus3`); the four stamp tags
  (`role`, `env`, `unit`, `stamp-id`) are a live contract with the AVNM
  network-group policy and must not be renamed. Apply the guideline's
  convention and the standard tag map (`Environment`, `Owner`, `ManagedBy`,
  `Repository`) to new resources and wrappers; renaming existing ones
  recreates them and is a planned change, not a drive-by.
