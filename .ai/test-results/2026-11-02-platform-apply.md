# 2026-11-02 - live/platform first apply (plan 004)

Applied from `live/platform` with `terragrunt run --all -- apply` after the
user elevated tenant-root access and assigned Owner at `/`.

| Unit | Result |
|---|---|
| management-groups | 6 added (mg-demo, -platform, -landingzones, -dev, -prod; Microsoft.Network register action) |
| network | 19 added, in two passes (see fixes) |

Verified with az (IDs withheld):

- `az account management-group show -n mg-demo -e -r`: platform MG holds
  the Pay-As-You-Go (management) and connectivity subscriptions; mg-demo-dev
  holds dev; mg-demo-prod empty (subscription not created yet).
- AVNM `avnm-platform` scope = `managementGroups: [mg-demo]`,
  access Connectivity + SecurityAdmin → the unit picked up the real MG id
  (the pre-apply plan had shown subscription scope from the mock).
- IPAM pools: `ipam-wus3`, `ipam-eus2` roots; `ipam-wus3-prod`,
  `ipam-eus2-prod` with parentPoolName set; all Succeeded.
- Policy assignment `avnm-ng-stamps-prod` present at mg-demo.
- Commits: Connectivity (cc-mesh-prod) and SecurityAdmin (sac-stamps)
  Deployed in westus3 and eastus2.
- Cost: $0 - no VNet is managed (no prod stamps exist).

Later the same day: prod subscription created in the portal (24h rate
limit had lifted), `TG_SUBSCRIPTION_PROD` set, providers registered,
`live/platform/management-groups` re-applied → plan showed exactly one
in-place change (`azurerm_management_group.env["prod"]`), and
`az account management-group show -n mg-demo -e -r` now lists all four
subscriptions: management + connectivity under platform, dev and prod
under their landing-zone groups. The MG-scoped membership policy inherits
to prod automatically - no network unit change.

Fixes found only by the live apply:

1. IPAM pool `display_name` rejects spaces (provider validation) →
   `aks-stamps-<location>` / `aks-stamps-<env>-<location>`.
2. Connectivity configuration: `applies_to_group.group_connectivity =
   "None"` with `global_mesh_enabled = true` → 400 "A group can be global
   only if the group connectivity is DirectlyConnected". Now
   `DirectlyConnected`.
3. Procedure: `az logout && az login` must come *between* elevateAccess and
   the root role assignment (docs/subscriptions.md updated).
