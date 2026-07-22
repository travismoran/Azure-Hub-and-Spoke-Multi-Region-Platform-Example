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
