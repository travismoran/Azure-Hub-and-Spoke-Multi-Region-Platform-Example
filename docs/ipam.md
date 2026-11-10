# IP address plan

Every VNet in every environment/region gets a globally non-overlapping slice
of `10.0.0.0/8`, so any peering (hub↔hub, the AVNM mesh between stamps, VPN
to on-prem) is possible without renumbering.

Two kinds of space: a small block per region for **hubs** (static, in the
connectivity subscription), and a **/12 root pool per region** for stamps,
split into one /16 per environment. The root → environment hierarchy is
exactly how the AVNM IPAM pools are nested, so the portal shows utilisation
per region and per environment.

| Region  | Hubs (/22 each, from)  | Stamp root pool (/12) | dev stamp pool (/16) | prod stamp pool (/16) |
|---------|------------------------|-----------------------|----------------------|-----------------------|
| westus3 | 10.0.0.0/16 (dev .0.0, prod .4.0) | 10.16.0.0/12 (10.16-10.31) | 10.16.0.0/16 | 10.17.0.0/16 |
| eastus2 | 10.1.0.0/16 (dev .0.0, prod .4.0) | 10.32.0.0/12 (10.32-10.47) | 10.32.0.0/16 | 10.33.0.0/16 |

The next region takes the next /16 for hubs (10.2.0.0/16) and the next /12
for stamps (10.48.0.0/12); the next environment takes the next /16 inside
each root. Fourteen more /16s remain in every root.

| Env  | Region  | Hub VNet (/22) | Stamp pool (/16) | First (static) stamp VNet (/22) |
|------|---------|----------------|------------------|---------------------------------|
| dev  | westus3 | 10.0.0.0/22    | 10.16.0.0/16     | 10.16.0.0/22                    |
| dev  | eastus2 | 10.1.0.0/22    | 10.32.0.0/16     | 10.32.0.0/22                    |
| prod | westus3 | 10.0.4.0/22    | 10.17.0.0/16     | 10.17.0.0/22                    |
| prod | eastus2 | 10.1.4.0/22    | 10.33.0.0/16     | 10.33.0.0/22                    |

Root pools live in `live/platform/platform.hcl`; `hub_address_space` and
`stamp_pool_prefix` live in each `live/<env>/<region>/region.hcl`. Who hands
out a stamp's /22 depends on `enable_avnm` in `env.hcl`:

- **off (dev default)**: the spoke uses the first /22 of the pool statically
  (`cidrsubnet(stamp_pool_prefix, 6, 0)` in `_envcommon/aks-spoke.hcl`).
- **on (prod)**: `modules/platform-network` creates the pool hierarchy in
  AVNM and the spoke VNet requests a `/stamp_prefix_length` from its
  environment's pool in its region. IPAM picks the prefix and guarantees it
  overlaps nothing else in the pool. 64 stamps fit per /16.

IPAM cannot remove a prefix from a pool or a VNet once allocated, so pools
are sized generously from day one.

## Inside a stamp /22

Every stamp is cut the same way, relative to its prefix (shown for
10.16.0.0/22). `modules/aks-spoke` derives these with `cidrsubnet` from
whatever prefix it has - static or IPAM-allocated - so the layout is
identical in both modes. A /21 stamp (`stamp_prefix_length = 21`) doubles
every subnet.

| Subnet              | Size       | Offset    | `cidrsubnet(vnet, bits, n)` | Purpose |
|---------------------|------------|-----------|-----------------------------|---------|
| `snet-aks-system`   | /25 (128)  | .0.0      | `(…, 3, 0)`                 | System node pool, ~120 nodes with surge |
| `snet-apiserver`    | /28 (16)   | .0.128    | `(…, 6, 8)`                 | API server VNet integration, delegated to AKS (`enable_api_server_vnet_integration`; otherwise reserved) |
| `snet-ilb`          | /27 (32)   | .0.160    | `(…, 5, 5)`                 | Internal load balancer frontends other stamps call over the mesh |
| *reserved*          | /27 (32)   | .0.192    | `(…, 5, 6)`                 | Private Link Service NAT IPs (not created) |
| *spare*             | /27 (32)   | .0.224    | `(…, 5, 7)`                 | |
| `snet-aks-user`     | /24 (256)  | .1.0      | `(…, 2, 1)`                 | User node pools, ~250 nodes |
| `snet-pe`           | /24 (256)  | .2.0      | `(…, 2, 2)`                 | Private endpoints (Key Vault, Storage, ACR, …) |
| *reserved*          | /24 (256)  | .3.0      | `(…, 2, 3)`                 | App Gateway for Containers or a second user pool (not created) |

The node subnets are unique per stamp, which makes them the caller identity
for network policies in other stamps (`node_subnet_prefixes` output).

## Inside the hub /22

Carved by `modules/hub`, each behind its toggle; the first /24 of the hub
range is laid out as four /26s:

| Subnet                        | CIDR                                     | Toggle |
|-------------------------------|------------------------------------------|--------|
| AzureFirewallSubnet           | `cidrsubnet(hub, 4, 0)` → 10.x.y.0/26    | `enable_firewall` |
| AzureFirewallManagementSubnet | `cidrsubnet(hub, 4, 1)` → 10.x.y.64/26   | `enable_firewall` (Basic SKU needs it) |
| snet-dns-inbound              | `cidrsubnet(hub, 6, 8)` → 10.x.y.128/28  | `enable_dns_resolver` (delegated to Microsoft.Network/dnsResolvers) |
| AzureBastionSubnet            | `cidrsubnet(hub, 4, 3)` → 10.x.y.192/26  | `enable_bastion` with a SKU other than Developer |

Firewall private IPs are deterministic - the first host (.4) of
AzureFirewallSubnet: dev 10.0.0.4 (westus3) / 10.1.0.4 (eastus2), prod
10.0.4.4 / 10.1.4.4. The AVNM routing rules (`enable_avnm_routing`) are
derived from the same arithmetic. The remaining three /24s of each hub /22
are spare (VPN gateway, future services).

## Cluster-internal ranges (identical in every cluster)

AKS runs Azure CNI in **overlay** mode: pod IPs are NAT'd behind the node IPs
and are never routed outside the cluster - not over peering and not over the
AVNM mesh. They only need to avoid the cluster's own VNet and its directly
connected VNets (all in `10.0.0.0/8` above), so the same ranges are reused
everywhere:

| Purpose        | CIDR             |
|----------------|------------------|
| Pods (overlay) | 192.168.0.0/16   |
| Services       | 172.20.0.0/16    |
| Cluster DNS    | 172.20.0.10      |

**Constraint to remember:** nothing connected to a stamp (peering, mesh,
on-prem) may use `192.168.0.0/16` or `172.20.0.0/16`. A /16 pod CIDR at a
/24 per node caps a cluster at ~250 nodes; the full design uses
`100.64.0.0/14` for ~1,000 - change `pod_cidr` before a stamp needs that
(it recreates the cluster).
