# 003 - Network platform: AVNM + IPAM + global mesh (stamp model)

- **Status**: in-progress (code + docs done, offline-validated; live verification pending). Superseded in scope by plan 004 (one AVNM at the top MG, multi-subscription) - the ADR-009 "per-env AVNM at subscription scope" adaptation is gone; verification steps 5-6 still apply.
- **Date**: 2026-11-01
- **Commits**: (this branch: feat/avnm-ipam-mesh)
- **Source**: Claude Docs "AKS Stamp Network Plan: AVNM + IPAM"
  (artifact Jf8d6zU7nfA1SMh1oAX7nY) - the enterprise design this adapts.

## Context

The source plan targets 100→500+ AKS stamps across subscriptions/regions:
one AVNM at the top MG, IPAM pools root→region→env, every stamp a /22 VNet
allocated from its pool, Azure CNI overlay, one global mesh per environment
for direct cluster-to-cluster, tag-driven network groups via Azure Policy,
coarse security admin guardrails, in-cluster Cilium policy keyed on node
subnets. This repo is a single-subscription teaching example with
independent env trees, so the plan is adapted rather than copied
(ADR-009..011). Goal of this iteration: make the repo demonstrate the stamp
model end-to-end in Terraform, behind a toggle, with zero change to the dev
cost floor.

## Design (as built)

- `modules/platform-network` (new, plain azurerm 4.81): RG, AVNM
  (subscription scope, Connectivity+SecurityAdmin), one IPAM pool per region
  over `region.hcl: stamp_pool_prefix`, network group `ng-stamps-<env>` +
  policy definition (`Microsoft.Network.Data` / `addToNetworkGroup`, match
  tags role=aks-stamp & env) + subscription assignment, connectivity config
  `cc-mesh-<env>` (Mesh, global), security admin config with rules
  100 allow-from-hubs / 200 deny-from-other-envs / 300 deny-internet
  high-risk ports, `azurerm_network_manager_deployment` per region per
  scope (security one re-triggered by a hash of rule inputs). All behind
  `var.enabled` → empty state, outputs null/{} when off.
- `modules/aks-spoke`: VNet from pool (`ipam_pools`, `prefix_length`) or
  static `/22`; subnets carved from `module.spoke_vnet.address_spaces[0]`
  with the AVM **subnet submodule** (needed because subnet prefixes derive
  from the VNet module's own output - a cycle inside one call). Layout:
  aks-system /25, ilb /27, aks-user /24, pe /24; apiserver/pls/spare/agc
  offsets reserved. VNet tags role/env/unit/stamp-id. `network_dataplane =
  cilium` when `network_policy = cilium` (prod was invalid before: Azure
  requires it). New outputs `node_subnet_prefixes`, `subnet_ids`,
  `spoke_address_space`.
- Live: `live/<env>/platform-network` unit; `_envcommon/platform-network.hcl`
  builds `regions` by reading every `region.hcl` listed in `env.hcl:
  regions`; `_envcommon/aks-spoke.hcl` adds `dependency "platform_network"`
  (mocked), `ipam_pool_id = lookup(pool_ids, region_short, null)`, static
  fallback `cidrsubnet(stamp_pool_prefix, 22-16, 0)`, and
  `firewall_routed_cidrs = enable_avnm ? [] : ["10.0.0.0/8"]`.
- env.hcl: dev `enable_avnm=false`; prod `true` + deny list of dev pools.

Rejected: static network-group members (would make platform state depend
on spoke state → circular with pool IDs); AVNM hub-and-spoke config for the
hub leg (plain peering already works, costs nothing); dropping the AVM vnet
module for raw azurerm (ADR-001 says compose AVM; the subnet submodule
solves the cycle); changing pod CIDR to 100.64.0.0/14 (overlay, unrouted,
not needed for the mesh; recreates clusters).

Cost: 0 in dev. Prod (plan-only) +~$73/mo per stamp VNet + IPAM per active
IP.

## Steps

1. [x] platform-network module - `terraform validate` ✅
2. [x] aks-spoke stamp layout + IPAM mode - `terraform validate` ✅
3. [x] live wiring + env/region hcl - `terragrunt run --all -- validate`
       from live/: 10/10 units ✅; `render` of inputs matches intent
       (dev static 10.11.0.0/22 + 10/8 UDR; prod enabled + deny list)
4. [x] docs: network-platform.md (new), ipam.md (rewrite), architecture,
       costs, README; ADR-009..011
5. [ ] Live: dev with `enable_avnm=true`, both regions - verify (a) AKS
       creation with "known after apply" subnet IDs, (b) VNets join
       `ng-stamps-dev` via policy within minutes, (c) mesh commit succeeds
       in both regions, (d) curl from wus3 pod to eus2 ILB in snet-ilb
       with NO firewalls, (e) rule 300 blocks a public LB on :22,
       (f) `node_subnet_prefixes` output → CiliumNetworkPolicy fromCIDR
       admits/denies as expected (needs network_policy=cilium in dev for
       the test).
6. [ ] Record evidence in .ai/test-results/, flip plan to complete.

## Verification

```bash
cd live && terragrunt run --all -- validate            # offline, done
cd live/dev && terragrunt run --all -- plan            # needs .env + az login
# after apply with enable_avnm=true:
az network manager group static-member list ...        # (dynamic members: portal/graph)
az network vnet show -g rg-aks-dev-wus3 -n vnet-aks-dev-wus3 --query addressSpace
```

## Risks / open questions

- First plan of an IPAM stamp shows every subnet + AKS subnet id as
  "known after apply"; AVM subnet submodule validations are `can()`-guarded
  but never exercised with unknowns here. Expected fine; confirm live.
- Policy-driven membership lags VNet creation by a few minutes; a mesh
  commit before membership is fine (members pick up committed configs).
- Deploying identity needs Resource Policy Contributor + IPAM Pool User
  (Owner covers both).
- Connected-group route vs. the hub firewall UDR: UDR wins, hence
  `firewall_routed_cidrs=[]` with AVNM on. If both toggles are on, firewall
  only sees non-stamp traffic.
- Security admin rule "deny stamp-to-stamp 22/10250" from the source plan
  deliberately not implemented (would deny intra-cluster kubelet traffic).
- Not yet ported from the source plan: AVNM routing (UseExisting) with UDR
  egress, IPAM "approved pool" deny policy, central svc DNS zone +
  external-dns + hub DNS resolver, API server VNet integration subnet.
