# 002 - Cross-region hub-to-hub transit via Azure Firewall

- **Status**: complete
- **Date**: 2026-07-21
- **Commits**: 35ba44d

## Context

Demo goal: call a workload in one cluster from the other cluster "via the
hub". VNet peering is non-transitive, so this requires a forwarding element
in each hub. Chosen over direct spoke↔spoke peering (which bypasses hubs) -
user decision; see ADR-007.

## Design (as built)

Data path: wus3 pod → node-subnet UDR (10.0.0.0/8 → FW1 10.10.0.4) → FW1
UDR (10.21.0.0/16 → FW2 10.20.0.4) over hub↔hub global peering → FW2 →
system route → eus2 spoke. All gated by `enable_firewall`:

- hub: Firewall Basic + policy (sku matches) + `rcg-private-transit` allow
  collection; `firewall_route_entries` var → firewall-subnet route table;
  optional `peer_hub` (both peering directions from the eus2 hub's state,
  which declares `dependency "remote_hub"` on the wus3 hub).
- aks-spoke: `firewall_private_ip` (from hub dependency output) triggers
  route table `rt-aks-<env>-<rs>` on the nodes subnet.
- Firewall IPs are deterministic (.4 of first /26) - written as constants
  in hub leaf files to avoid a circular dependency between hub states (ADR-005).

## Verification (done)

curl from wus3 pod to eus2 internal LB 10.21.0.5 returned the nginx page ✅
Evidence: .ai/test-results/2026-07-21-aks-e2e.md

## Quirks hit (recorded as ADRs / in rules)

- AVM hubnetworking: must pass `default_ip_configuration` + explicit
  `name`s - unguarded null derefs; optional attrs exist-as-null defeat try().
- BYO-VNet AKS: control-plane identity needs Network Contributor on spoke
  vnet + node route table, else internal LBs stay `<pending>`.
