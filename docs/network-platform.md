# Network platform: AVNM, IPAM and a global mesh

This is the repo's adaptation of a larger design, "AKS Stamp Network Plan:
AVNM + IPAM", for running hundreds of AKS *stamps* (one cluster + VNet each)
across regions and subscriptions. The full design runs one Azure Virtual
Network Manager (AVNM) at the top management group, carves one IPAM root
pool per region into environment pools, and lets every stamp take its own
/22 automatically. This repo keeps the same resources and the same tag
contract, scaled to one subscription and independent `dev`/`prod` trees.

Everything in this document is behind `enable_avnm` in `live/<env>/env.hcl`
(off in dev, on in prod) and lives in `modules/platform-network`, applied
once per environment from `live/<env>/platform-network`.

## What it does

| Piece | Resource | What it gives you |
|---|---|---|
| AVNM instance | `azurerm_network_manager`, subscription scope, Connectivity + SecurityAdmin | One place for groups, mesh and guardrails |
| IPAM pools | `azurerm_network_manager_ipam_pool`, one per region (`stamp_pool_prefix` in `region.hcl`) | Stamps request "a /22", never pick a CIDR; overlap is impossible |
| Network group | `azurerm_network_manager_network_group` + Azure Policy (`Microsoft.Network.Data`, `addToNetworkGroup`) | Any VNet tagged `role=aks-stamp`, `env=<env>` joins automatically |
| Global mesh | `azurerm_network_manager_connectivity_configuration`, topology Mesh, global | Every stamp of the environment routes directly to every other, in any region |
| Security admin | `azurerm_network_manager_security_admin_configuration` + rules 100/200/300 | Guardrails evaluated before NSGs, un-overridable per stamp |
| Commits | `azurerm_network_manager_deployment`, one per region per scope | AVNM configurations do nothing until committed per region |

And on the stamp side (`modules/aks-spoke`):

- The VNet is allocated from the region's pool (`ipam_pools` on the AVM
  virtualnetwork module, `prefix_length = stamp_prefix_length`) and tagged
  `role`, `env`, `unit`, `stamp-id`.
- Subnets are carved from whatever prefix IPAM returns, using the fixed
  layout in [ipam.md](ipam.md), with the AVM subnet submodule (static subnets
  inside an IPAM-allocated VNet is a supported mix).
- No UDR for other stamps' prefixes: the firewall transit route is dropped
  (`firewall_routed_cidrs = []`) because a UDR would override the
  connected-group route and silently pull east-west traffic off the mesh.
- `node_subnet_prefixes` is exported: each stamp's node subnets are unique,
  so they are a reliable *source identity* for in-cluster network policies
  in the stamps it calls.

## Mesh versus hub-firewall transit

The repo now has two ways to get cluster-to-cluster traffic across regions:

| | Hub firewall transit (`enable_firewall`) | AVNM global mesh (`enable_avnm`) |
|---|---|---|
| Path | spoke → FW1 → hub↔hub peering → FW2 → spoke | spoke → spoke (connected group route) |
| Cost driver | ~$300/mo per Firewall Basic | ~$0.10/hr per managed VNet + IPAM per active IP |
| Inspection | Firewall sees every flow | None at layer 3; policy moves in-cluster |
| Scale | Per-hub route entries per remote spoke | Tag a VNet, done; 250 VNets / 128k addresses per group by default |
| Verified | Yes, 2026-07-21 (`.ai/test-results/`) | Not yet (needs a live apply with `enable_avnm = true`) |

With both on, the firewall still handles anything that is not another
stamp (there is no 10/8 route any more), and the mesh carries east-west.

## How a call reaches a service over the mesh

1. The provider stamp exposes a Kubernetes `Service` of type `LoadBalancer`
   with `service.beta.kubernetes.io/azure-load-balancer-internal: "true"`
   and `...-internal-subnet: "snet-ilb"`, and `externalTrafficPolicy: Local`
   so the caller's node IP reaches the pods unchanged.
2. The consumer pod's traffic leaves its node with the node's IP (CNI
   overlay SNAT) and follows the connected-group route straight to the
   provider VNet. No hop through either hub.
3. A network policy on the provider admits the caller stamp's
   `node_subnet_prefixes` on the service port. With `network_policy =
   "cilium"` (prod) that is a `CiliumNetworkPolicy` with `fromCIDR`.

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata: { name: orders-api-callers }
spec:
  endpointSelector: { matchLabels: { app: orders-api } }
  ingress:
    - fromCIDR:           # node_subnet_prefixes of the stamps allowed to call
        - 10.121.0.0/25   #   prod/eus2 system nodes
        - 10.121.1.0/24   #   prod/eus2 user nodes
      toPorts: [{ ports: [{ port: "8443", protocol: TCP }] }]
```

Name resolution across stamps (a central private zone such as
`svc.platform.internal` fed by external-dns, linked to the hubs, with stamps
using the hub's DNS Private Resolver) is part of the full design and not yet
in this repo - see the backlog.

## Security admin rules

| Priority | Rule | Action | Source |
|---|---|---|---|
| 100 | `allow-from-hubs` | AlwaysAllow | Every region's hub VNet range |
| 200 | `deny-inbound-from-other-envs` | Deny | `security_admin_deny_inbound_from` (prod lists the dev pools) |
| 300 | `deny-internet-high-risk-ports` | Deny TCP 22, 3389, 445, 1433 | `Internet` service tag |

Deliberately absent: "deny stamp-to-stamp on 22/10250". With prefix sources
it would also deny a cluster's own node-to-node kubelet traffic (scrapers
SNAT to node IPs), since a rule cannot exclude "my own subnet". Do that per
stamp with NSGs or in-cluster policy.

## Turning it on

```bash
# in live/<env>/env.hcl
enable_avnm = true

cd live/dev && terragrunt run --all -- apply      # platform-network → hubs → spokes
```

Apply from the environment folder, not a region folder: `platform-network`
is an *external* dependency of every spoke. From a region folder, pass
`--queue-include-external` or apply `live/<env>/platform-network` first.
(Validation from anywhere keeps working: the dependency is mocked.)

Switching an existing spoke between static and IPAM addressing recreates
its VNet, and therefore the cluster. Nothing in this repo is applied today,
so that is free; on a live platform, pick one mode per environment up front.

The deploying identity needs, beyond what the rest of the repo needs:
Resource Policy Contributor (the membership policy is an Azure Policy
definition + assignment at subscription scope) and `IPAM Pool User` on the
pools (contained in Contributor/Owner, which this example assumes).

## Limits that matter

| Limit | Default | Here |
|---|---|---|
| Private addresses per connected group | 128,000 (more by request) | 125 stamps at /22 per environment; file the request early for prod |
| VNets per connected group | 250 (3,000 high-scale mesh; 5,000 by request) | Plenty for an example; the full design needs high-scale mesh |
| Connected groups per VNet | 2 | Each stamp uses one |
| Connected-group regions | Listed regions only | westus3 and eastus2 are listed; check any new region |
| Security admin rules | 100 per level; 20,000 prefixes | Guardrails only, by design |
| IPAM | Prefixes cannot be removed from a pool or VNet once allocated | Size `stamp_pool_prefix` generously (a /16 = 64 stamps) |

## Differences from the full design, and why

| Full design | This repo | Why |
|---|---|---|
| One AVNM at the top management group, pools root → region → env | One AVNM per environment at subscription scope, one pool per region | One subscription, independent env trees with separate state; same resources and tags, narrower scope |
| Per-region /12 roots split into prod /13, stage /14, QA /15 | The existing per-env/region /16 (was the whole spoke VNet) becomes the pool; stamps take /22s from it | No renumbering; `docs/ipam.md` scheme stays valid |
| AVNM hub-and-spoke connectivity config, one hub per region per env class | Plain hub↔spoke peering created by the spoke (unchanged) | Already works, zero AVNM cost for the hub leg |
| AVNM routing config (UseExisting) adds 0.0.0.0/0 → firewall to the stamp route table | Not implemented | The repo does not use `userDefinedRouting` egress; backlog |
| IPAM "VNet must allocate from an approved pool" deny policy, tag inheritance policies | Not implemented | One deploying identity, no landing-zone MGs to assign to; backlog |
| Central `svc.platform.internal` zone + external-dns + hub DNS resolver | Not implemented | Needs a hub DNS Private Resolver (~$180/mo per hub); backlog |
| Private cluster + API server VNet integration | prod private cluster as before; `snet-aks-apiserver` offset reserved, not created | Avoid dead config |
| Pod CIDR 100.64.0.0/14 | Unchanged `192.168.0.0/16` | Overlay CIDRs are never routed, so the mesh does not care; switch when a stamp needs > 250 nodes |

## Open questions carried over

- Confirm the 128,000-address scaling request process and whether
  high-scale mesh still needs `AllowHighScaleConnectedGroup` registration.
- Does AKS creation succeed with the IPAM-allocated subnet IDs being
  "known after apply" on the first plan? (Expected yes; verify in the first
  live apply - plan 003.)
- Fleet Manager cross-cluster networking as a later service-discovery layer
  normally needs unique pod CIDRs; this repo reuses one overlay CIDR.
