# Architectural Decision Records

Newest last. One section per decision; never delete - supersede.

## ADR-001: Compose AVM resource modules; do not use avm-ptn-aks-enterprise

2026-07-21 · Accepted

The official pattern module (v0.1.0, only release) hardcodes ~$1,700/mo
(Firewall Standard, ACR Premium, private cluster + UDR, D16ds_v5 system
pool), creates its own VNet with no existing-subnet input, and exports no
VNet ID - hub-spoke peering impossible, cost goals impossible. We compose
hubnetworking 0.13.2 / virtualnetwork 0.19.0 / managedcluster 0.6.7 /
containerregistry 0.5.1 / operationalinsights 0.5.1, pinned exactly.

## ADR-002: Classic terragrunt includes, not stacks

2026-07-21 · Accepted

`root.hcl` + `_envcommon` + deep-merge includes. The experimental
`terragrunt.stack.hcl` would shrink leaves further but is less universally
understood; this is a teaching repo. Revisit if the matrix grows.

## ADR-003: All real values via env vars; local-backend fallback

2026-07-21 · Accepted

Public repo → subscription/tenant/object IDs, storage names, and IPs live
only in `.env` (gitignored) / GitHub repo variables. When `TG_STATE_*` is
unset, root.hcl swaps the azurerm backend for a throwaway local backend -
this (not `init -backend=false`, which breaks terragrunt dependency output
fetching) is what makes the whole graph validate offline.

## ADR-004: Public API server + authorized IPs in dev; private only in prod

2026-07-21 · Accepted

Private clusters need a jumpbox/Bastion/VPN (~$140+/mo) to be usable.
Dev uses `api_server_authorized_ip_ranges` = TG_AUTHORIZED_IP instead.

## ADR-005: Deterministic firewall private IPs as constants

2026-07-21 · Accepted

Hub A's firewall routes need hub B's firewall IP and vice versa - a circular
dependency between the two hub states. Azure always assigns the firewall the
first host (.4) of AzureFirewallSubnet, which we always carve as the first
/26 of the hub /22, so leaf files hardcode `10.x.0.4`. Verified live: both
firewalls landed on the predicted IPs. Trade-off: if the carve ever changes,
update `firewall_route_entries` in the hub leaves.

## ADR-006: RBAC-only state storage (no shared keys)

2026-07-21 · Accepted

`use_azuread_auth = true` + `--allow-shared-key-access false`; humans and CI
get Storage Blob Data Contributor. No storage keys exist to leak.

## ADR-007: Cross-region transit via per-hub firewalls, not spoke peering

2026-07-21 · Accepted (user decision)

VNet peering is non-transitive; direct spoke↔spoke peering would work and
cost ~nothing but bypasses the hubs. Chosen: Firewall Basic per hub +
hub↔hub global peering + node-subnet UDR (10.0.0.0/8 → local FW) + per-hub
firewall routes to remote spokes. All behind `enable_firewall` so the repo
still has a cheap mode. Verified 2026-07-21 (see test-results).

## ADR-008: AVM quirks encoded in wrappers (learned the hard way)

2026-07-21 · Accepted

- hubnetworking dereferences `firewall.default_ip_configuration` and uses
  `firewall_policy.name` without guards; optional object attrs exist-as-null
  so its `try()` fallbacks never fire → wrapper passes all of them explicitly.
- managedcluster is azapi-based: `parent_id` (RG resource ID), not
  `resource_group_name`; kubelet identity output attr is `.objectId`.
- containerregistry defaults to Premium + zone redundancy → wrapper forces
  `zone_redundancy_enabled=false` for Basic.
- BYO-VNet AKS: control-plane identity needs Network Contributor on the
  spoke VNet (+ node route table) or internal LBs stay `<pending>`.

## ADR-009: AVNM global mesh as the second east-west path; per-env AVNM at subscription scope

2026-11-01 · Accepted

Adapting the "AKS Stamp Network Plan" (one AVNM at the top MG, pools
root→region→env, one global mesh per environment). This repo has one
subscription and independent dev/prod trees with separate state, so it runs
**one AVNM per environment, scoped to the subscription**, one IPAM pool per
region - same resources, same tag contract (`role=aks-stamp`, `env`, `unit`,
`stamp-id`), narrower scope. Membership is dynamic via an Azure Policy in
`Microsoft.Network.Data` mode: the platform state never references a spoke
(static members would be circular with the pool-ID dependency). Hubs stay
out of the mesh and keep plain hub↔spoke peering (no AVNM hub-and-spoke
config: already works, free). The mesh coexists with ADR-007's firewall
transit as an alternative, not a replacement: `enable_avnm` empties
`firewall_routed_cidrs` because a UDR overrides the connected-group route.
Off in dev (AVNM bills per managed VNet), on in prod (plan-only).

## ADR-010: Spokes are uniform /22 stamps; subnets carved via the AVM subnet submodule

2026-11-01 · Accepted

Every spoke VNet is a /22 (`stamp_prefix_length`) with a fixed relative
layout (system /25, ilb /27, user /24, pe /24; apiserver/pls/agc offsets
reserved), allocated by IPAM when `enable_avnm` or statically as the first
/22 of `region.hcl: stamp_pool_prefix` otherwise. The former spoke /16 is
now the pool (64 stamps). Subnet prefixes are `cidrsubnet()` of the VNet
module's `address_spaces[0]` output, which cannot feed the same module's
`subnets` input (cycle) - so subnets use
`avm-res-network-virtualnetwork//modules/subnet` separately. The submodule
README explicitly supports "IPAM VNet + traditional subnet" (answers the
source plan's open question). Node subnets are unique per stamp →
`node_subnet_prefixes` output is the caller identity for in-cluster policy.
Trade-off: switching a live spoke between modes recreates VNet + cluster.

## ADR-012: Landing-zone layout - subscription per role, management groups, one AVNM at the top MG

2026-11-01 · Accepted (supersedes the "per-env AVNM at subscription scope" half of ADR-009)

The enterprise plan's real scope costs nothing extra (MGs/subscriptions are
free; AVNM bills per managed VNet regardless of scope), so the repo now has
it: `management` (existing sub, holds state), `connectivity` (all hubs +
AVNM + IPAM), `dev`/`prod` (stamps) under `mg-<prefix>` → `-platform` /
`-landingzones` → `-<env>`. One `modules/platform-network` instance at
`live/platform/network`, scoped to the top MG, with /12 root pools per
region split into /16 env pools (nested IPAM pools), MG-scoped membership
policies, one mesh per env, and rule 200 derived from the other envs'
pools. Subscription placement is a path→env-var map in `live/root.hcl`
(hubs and platform → connectivity; stamps → `TG_SUBSCRIPTION_<ENV>`), with
`ARM_SUBSCRIPTION_ID` as the fallback so single-subscription use is
unchanged; `enable_management_groups = false` keeps the AVNM at
subscription scope for tenants where root elevation is impossible.
Subscriptions are created in the portal, not vended: the billing account is
MOSP (personal Pay-As-You-Go), which the subscription alias API does not
accept; a vending module would be dead code here. Renumbered so the pool
hierarchy is real: hubs 10.0/10.1.0.0/16 per region, stamp roots
10.16/10.32.0.0/12 (nothing was deployed, so free). Hub↔spoke peering
crosses subscriptions - fine because the AVM peering submodule uses full
resource IDs (azapi) for both directions.

## ADR-011: Cilium dataplane follows network_policy

2026-11-01 · Accepted

Azure rejects `networkPolicy=cilium` without `networkDataplane=cilium`; prod
(plan-only) had the former without the latter. The wrapper now derives
`network_dataplane` from `network_policy`, keeping one toggle in env.hcl.
