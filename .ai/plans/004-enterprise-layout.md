# 004 - Enterprise layout: subscriptions per role, management groups, one AVNM at the top MG

- **Status**: complete (live/platform applied 2026-11-02; prod subscription created and placed under mg-demo-prod the same day). Follow-on: plan 003 step 5 (dev mesh live verification).
- **Date**: 2026-11-01
- **Branch**: feat/avnm-ipam-mesh (on top of plan 003)
- **Source**: the same Claude Docs plan as 003 - this iteration removes the
  "one subscription" adaptation (ADR-009) and lands the plan's real scope.

## Context

User asked whether the full enterprise architecture (one AVNM at the top
management group, more subscriptions) costs anything. Answer: no fixed
cost - MGs/subscriptions are free, AVNM bills per managed VNet whatever its
scope. Blocker was prerequisites, not money. Billing account is
`MicrosoftOnlineServicesProgram` (personal Pay-As-You-Go) → no API
subscription vending; user created `connectivity` and `dev` by hand in the
portal (2026-11-01), `prod` rate-limited for 24h. Existing `Pay-As-You-Go`
subscription keeps the state storage and becomes the *management*
subscription.

## Design (as built)

- `modules/management-groups` (new): `mg-<prefix>` → `-platform`
  (management + connectivity subs) and `-landingzones` → `-<env>` (env
  sub). Placement from a role→ID map; empty IDs skipped; duplicate ID
  (single-sub mode) goes to the lexically first role. `azapi_resource_action`
  POSTs `providers/Microsoft.Network/register` on the top MG (AVNM-at-MG
  prerequisite). `enabled=false` → nothing, null top MG id.
- `modules/platform-network` rewritten for one tenant-wide instance:
  scope = top MG (or own subscription when null), root IPAM pool per region
  (`/12`) with child pool per *enabled* environment (`parent_pool_name`),
  network group + policy definition + **MG-scoped** assignment (24-char
  name cap) per env, mesh per env, one regional Connectivity commit listing
  every env's mesh (a commit replaces the region's config set), one
  security admin config with a rule collection per env; rule 200's sources
  are now *derived* (every other env's stamp pools, enabled or not) - the
  `security_admin_deny_inbound_from` env.hcl knob is gone. Outputs keyed
  env → region.
- `live/root.hcl`: subscription placement by unit path
  (management-groups→management, network/hub→connectivity,
  aks-spoke→`TG_SUBSCRIPTION_<ENV>`), fallback `ARM_SUBSCRIPTION_ID`,
  provider block omits `subscription_id` when nothing is set (offline);
  backend gets `subscription_id` = management sub. Set-but-empty
  `TG_SUBSCRIPTION_PROD=""` → prod spokes have no subscription (plan fails
  loudly; MG created empty).
- `live/platform/{platform.hcl,management-groups,network}`; per-env
  `platform-network` units removed; spoke dependency path
  `../../../platform/network`, lookup `ipam_pool_ids[env][region]`.
- Renumbered (ADR-012): hubs 10.0.0.0/16 (wus3) / 10.1.0.0/16 (eus2), /22
  per env at .0.0 (dev) and .4.0 (prod); stamp roots 10.16.0.0/12 (wus3),
  10.32.0.0/12 (eus2); env pools .16/.17 and .32/.33 /16s. Hub transit
  leaves updated (FW IPs 10.0.0.4 / 10.1.0.4).
- `bootstrap/register-providers.sh` (idempotent, every `TG_SUBSCRIPTION_*`);
  `.env.example` + `plan.yml` carry the new vars.

Rejected: generating the provider from `_envcommon` (two includes with the
same generate label - undefined precedence); an `azapi` provider block in
root (modules without azapi in required_providers would fail init - azapi
callers all use full resource IDs so no subscription needed); MGs created
by az CLI in bootstrap (Terraform-managed is the point).

## Steps

1. [x] management-groups module - validate ✅
2. [x] platform-network at MG scope + pool hierarchy - validate ✅
3. [x] root.hcl placement, platform folder, renumber, bootstrap, CI -
       `terragrunt run --all -- validate` from live/: 10/10 ✅; render:
       placement per unit correct with placeholder IDs; dev spoke static
       10.16.0.0/22 + 10/8 UDR; platform inputs dev disabled / prod enabled
4. [x] docs: subscriptions.md (new), ipam.md, network-platform.md,
       architecture.md, README, costs, bootstrap, OIDC; ADR-012
5. [x] Azure: providers registered in connectivity + dev (+ management
       already) 2026-11-01
6. [x] User elevated tenant-root access + Owner at `/` (2026-11-02);
       `.env` has TG_SUBSCRIPTION_{MANAGEMENT,CONNECTIVITY,DEV}, PROD=""
7. [x] Applied `live/platform` 2026-11-02: MG tree, placement, AVNM scope
       = mg-demo, nested pools, MG policy assignment, 4 commits Deployed.
       Two live-only fixes (pool display_name, DirectlyConnected).
8. [x] 2026-11-02: prod sub created (portal) → `TG_SUBSCRIPTION_PROD` →
       register-providers (12 namespaces) → management-groups apply: 1
       in-place change, prod now under mg-demo-prod. Prod stamps still
       never applied.
9. [ ] Then plan 003 step 5 (live mesh verification in dev with
       enable_avnm=true) - now cross-subscription too.

## Risks / open questions

- `azurerm_management_group` with `subscription_ids` moves subs out of the
  Tenant Root Group: needs write on the root (hence elevation).
- A VNet in the dev sub allocating from a pool in the connectivity sub:
  identity needs IPAM Pool User on the pool (Owner covers); confirm live.
- MG-scope `Microsoft.Network.Data` policy assignment propagation to new
  subs (prod tomorrow) is automatic by inheritance - confirm membership
  after the first prod stamp someday (plan-only, so likely never here).
- Dropping a sub from `subscriptions` does not move it back to root; it
  stays in its MG until moved by hand.
