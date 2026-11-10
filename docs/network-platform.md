# Network platform: AVNM, IPAM and a global mesh

This is the repo's adaptation of a larger design, "AKS Stamp Network Plan:
AVNM + IPAM", for running hundreds of AKS *stamps* (one cluster + VNet each)
across regions and subscriptions: **one Azure Virtual Network Manager
(AVNM) at the top management group**, one IPAM root pool per region carved
into environment pools, every stamp taking its own /22 automatically, one
global mesh per environment, tag-driven membership, coarse security admin
guardrails. The layout it sits on is in [subscriptions.md](subscriptions.md).

The platform lives in `modules/platform-network`, applied **once** from
`live/platform/network` into the connectivity subscription. Each
environment opts in with `enable_avnm` in its `env.hcl` (off in dev, on in
prod): that creates the environment's pools, network group, mesh and rule
collection, and switches its stamps to IPAM addressing. With no environment
opted in the unit creates nothing.

## What it does

| Piece | Resource | What it gives you |
|---|---|---|
| AVNM instance | `azurerm_network_manager` scoped to `mg-<prefix>` (or the subscription in single-subscription mode), Connectivity + SecurityAdmin | One place for groups, meshes and guardrails across every landing-zone subscription |
| IPAM pools | `azurerm_network_manager_ipam_pool`: one root per region (`root_pool_prefix` in `platform.hcl`) with one child per environment (`stamp_pool_prefix` in `region.hcl`) | Stamps request "a /22", never pick a CIDR; overlap is impossible; utilisation visible per region and per environment |
| Network groups | `azurerm_network_manager_network_group` per environment + Azure Policy (`Microsoft.Network.Data`, `addToNetworkGroup`) assigned at the management group | Any VNet tagged `role=aks-stamp`, `env=<env>` in any subscription joins its environment's group automatically |
| Global meshes | `azurerm_network_manager_connectivity_configuration` per environment, topology Mesh, global | Every stamp of an environment routes directly to every other, in any region or subscription; environments never share a mesh |
| Security admin | one `azurerm_network_manager_security_admin_configuration`, one rule collection per environment, rules 100/200/300 | Guardrails evaluated before NSGs, un-overridable per stamp |
| Commits | `azurerm_network_manager_deployment`, one per region per scope, listing every environment's configuration | AVNM configurations do nothing until committed per region |

And on the stamp side (`modules/aks-spoke`):

- The VNet is allocated from its environment's pool in its region
  (`ipam_pools` on the AVM virtualnetwork module, `prefix_length =
  stamp_prefix_length`) and tagged `role`, `env`, `unit`, `stamp-id`.
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
| Verified | Yes, 2026-07-21 (`.ai/test-results/`) | Yes, 2026-11-02, cross-subscription (`.ai/test-results/2026-11-02-avnm-mesh-e2e.md`) |

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
        - 10.33.0.0/25    #   prod/eus2 system nodes
        - 10.33.1.0/24    #   prod/eus2 user nodes
      toPorts: [{ ports: [{ port: "8443", protocol: TCP }] }]
```

Name resolution across stamps (a central private zone such as
`svc.platform.internal` fed by external-dns, linked to the hubs, with stamps
using the hub's DNS Private Resolver) is part of the full design and not yet
in this repo - see the backlog.

## Security admin rules

One rule collection per environment, applied to that environment's group:

| Priority | Rule | Action | Source |
|---|---|---|---|
| 100 | `allow-from-hubs` | AlwaysAllow | The environment's hub VNet ranges, every region |
| 200 | `deny-inbound-from-other-envs` | Deny | Every *other* environment's stamp pools - derived from their `region.hcl`, opted in to AVNM or not (static stamps use the same ranges) |
| 300 | `deny-internet-high-risk-ports` | Deny TCP 22, 3389, 445, 1433 | `Internet` service tag |

Deliberately absent: "deny stamp-to-stamp on 22/10250". With prefix sources
it would also deny a cluster's own node-to-node kubelet traffic (scrapers
SNAT to node IPs), since a rule cannot exclude "my own subnet". Do that per
stamp with NSGs or in-cluster policy.

## Turning it on

```bash
# in live/<env>/env.hcl
enable_avnm = true

cd live/platform && terragrunt run --all -- apply   # management groups → network platform
cd ../dev        && terragrunt run --all -- apply   # hubs → spokes
```

`live/platform/network` is an *external* dependency of every spoke: apply
the platform first (or pass `--queue-include-external` from an environment
or region folder). Validation from anywhere keeps working: the dependency
is mocked.

Switching an existing spoke between static and IPAM addressing recreates
its VNet, and therefore the cluster. Nothing in this repo is applied today,
so that is free; on a live platform, pick one mode per environment up front.

The deploying identity needs, beyond what the rest of the repo needs:
Resource Policy Contributor on `mg-<prefix>` (the membership policies are
Azure Policy definitions + assignments at the management group) and `IPAM
Pool User` on the pools (contained in Contributor/Owner, which this example
assumes - see [subscriptions.md](subscriptions.md)). AVNM at management
group scope also needs `Microsoft.Network` registered on that management
group; `modules/management-groups` does it.

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
| One AVNM at the top management group, pools root → region → env | Same: one AVNM at `mg-<prefix>` in the connectivity subscription, a /12 root per region split per environment | Done in the enterprise-layout iteration (plan 004); single-subscription mode kept as a fallback |
| Per-region /12 roots split into prod /13, stage /14, QA /15 | Per-region /12 roots split into /16 per environment (64 stamps each) | Two environments; the split is one number per `region.hcl` |
| Subscriptions vended by Terraform (`avm-ptn-alz-sub-vending`) | Created in the portal, referenced by ID from env vars | Needs an EA/MCA/MPA billing account; a personal Pay-As-You-Go account has no vendable billing scope |
| AVNM hub-and-spoke connectivity config, one hub per region per env class | Plain hub↔spoke peering created by the spoke (unchanged) | Already works, zero AVNM cost for the hub leg |
| AVNM routing config (UseExisting) adds 0.0.0.0/0 → firewall to the stamp route table | Not implemented | The repo does not use `userDefinedRouting` egress; backlog |
| IPAM "VNet must allocate from an approved pool" deny policy, tag inheritance policies | Not implemented | Landing-zone management groups now exist to assign them to; backlog (Audit first) |
| Central `svc.platform.internal` zone + external-dns + hub DNS resolver | Not implemented | Needs a hub DNS Private Resolver (~$180/mo per hub); backlog |
| Private cluster + API server VNet integration | prod private cluster as before; `snet-aks-apiserver` offset reserved, not created | Avoid dead config |
| Pod CIDR 100.64.0.0/14 | Unchanged `192.168.0.0/16` | Overlay CIDRs are never routed, so the mesh does not care; switch when a stamp needs > 250 nodes |

## Open questions carried over

- Confirm the 128,000-address scaling request process and whether
  high-scale mesh still needs `AllowHighScaleConnectedGroup` registration.
- ~~Does AKS creation succeed with the IPAM-allocated subnet IDs being
  "known after apply"?~~ Yes (2026-11-02). Policy-driven membership took
  ~35 minutes on first use, not "a few"; commit the mesh anyway, members
  pick it up when they join.
- Fleet Manager cross-cluster networking as a later service-discovery layer
  normally needs unique pod CIDRs; this repo reuses one overlay CIDR.


## Optional layers (all off by default)

Added 2026-11-07 (ADR-016/017); none has been applied yet. Each is a toggle
in `env.hcl` or `platform.hcl`, and the modules validate with them on.

### Egress through the hub firewall

`aks_outbound_type = "userDefinedRouting"` (requires `enable_firewall`):
the stamp's node route table gets `0.0.0.0/0 → hub firewall` and the hub's
firewall policy gets the AKS required-egress collection (`rcg-aks-egress`:
FQDN tag `AzureKubernetesService`, tunnel ports 1194/9000 to
`AzureCloud.<region>`, NTP, common registries). The LB public IP stays for
inbound only. With `enable_avnm_routing = true` on top, the default route is
instead pushed by an AVNM **routing configuration** in `UseExisting` mode:
one per environment, with a rule collection per env/region bound to a
regional network group (`ng-stamps-<env>-<region>`, membership by tags +
location) whose next hop is that region's deterministic firewall IP. The
stamp module then skips its own default route. Either way the mesh stays
the east-west path; routing only moves north-south.

### Approved-pool policy

`enable_ipam_pool_policy` (platform.hcl) assigns a custom policy at the AVNM
scope: any VNet tagged `role=aks-stamp` whose address space is not allocated
from one of the environment IPAM pools is non-compliant. Alias:
`Microsoft.Network/virtualnetworks/addressSpace.ipamPoolPrefixAllocations[*].pool.id`.
`ipam_pool_policy_effect` starts at `Audit`; switch to `Deny` once the
compliance view is clean.

### Service discovery: central private DNS

`enable_private_dns` (env.hcl) creates `svc.<env>.platform.internal` in
`rg-dns-platform` (connectivity subscription). Every hub and stamp links its
own VNet to the zone from its own state (by zone ID, via azapi because the
link crosses subscriptions), so adding a stamp never touches the platform
state. Inside Azure that is enough: Azure DNS answers for linked zones.
`enable_external_dns_identity` adds a workload identity per stamp
(`id-external-dns-<stamp-id>`, federated to the cluster's OIDC issuer for
`external-dns/external-dns`) with Private DNS Zone Contributor on the zone
and Reader on `rg-dns-platform`; the client ID is the stamp output
`external_dns_client_id`. `enable_dns_resolver` (hub) adds a DNS Private
Resolver inbound endpoint (`snet-dns-inbound`, output
`dns_resolver_inbound_ip`) for on-prem/VPN clients.

### API server VNet integration

`enable_api_server_vnet_integration` carves `snet-apiserver` (/28, offset
.0.128, delegated to AKS) and projects the API server into the stamp VNet.
Nodes reach the control plane privately without a private cluster.

### Caller policies

See `catalog/README.md`: `catalog/stamps.json` says which stamps may call
which; `scripts/gen-cilium-caller-policies.sh` renders a
CiliumClusterwideNetworkPolicy per stamp from the stamps' unique node
subnets.
