# IP address plan

Every VNet in every environment/region gets a globally non-overlapping slice
of `10.0.0.0/8`, so any peering (hub↔hub, the AVNM mesh between stamps, VPN
to on-prem) is possible without renumbering.

Scheme: second octet = `env_base + region_index * 10`, where dev starts at 10,
prod at 110, and regions are numbered westus3=0, eastus2=1. The hub takes the
`.X0.0.0/22`; the `.X1.0.0/16` is the **stamp pool** for that env/region,
from which every AKS stamp VNet takes a /22.

| Env  | Region  | Hub VNet (/22) | Stamp pool (/16) | First stamp VNet (/22) |
|------|---------|----------------|------------------|------------------------|
| dev  | westus3 | 10.10.0.0/22   | 10.11.0.0/16     | 10.11.0.0/22           |
| dev  | eastus2 | 10.20.0.0/22   | 10.21.0.0/16     | 10.21.0.0/22           |
| prod | westus3 | 10.110.0.0/22  | 10.111.0.0/16    | 10.111.0.0/22          |
| prod | eastus2 | 10.120.0.0/22  | 10.121.0.0/16    | 10.121.0.0/22          |

`hub_address_space` and `stamp_pool_prefix` live in each
`live/<env>/<region>/region.hcl`. Who hands out the /22 depends on
`enable_avnm` in `env.hcl`:

- **off (dev default)**: the spoke uses the first /22 of the pool statically
  (`cidrsubnet(stamp_pool_prefix, 6, 0)` in `_envcommon/aks-spoke.hcl`).
- **on (prod)**: `modules/platform-network` creates one AVNM IPAM pool per
  region over `stamp_pool_prefix`, and the spoke VNet requests a
  `/stamp_prefix_length` from it. IPAM picks the prefix and guarantees it
  overlaps nothing else in the pool. 64 stamps fit per /16.

IPAM cannot remove a prefix from a pool or a VNet once allocated, so pools
are sized generously from day one.

## Inside a stamp /22

Every stamp is cut the same way, relative to its prefix (shown for
10.11.0.0/22). `modules/aks-spoke` derives these with `cidrsubnet` from
whatever prefix it has - static or IPAM-allocated - so the layout is
identical in both modes. A /21 stamp (`stamp_prefix_length = 21`) doubles
every subnet.

| Subnet              | Size       | Offset    | `cidrsubnet(vnet, bits, n)` | Purpose |
|---------------------|------------|-----------|-----------------------------|---------|
| `snet-aks-system`   | /25 (128)  | .0.0      | `(…, 3, 0)`                 | System node pool, ~120 nodes with surge |
| *reserved*          | /28 (16)   | .0.128    | `(…, 6, 8)`                 | API server VNet integration (not created) |
| `snet-ilb`          | /27 (32)   | .0.160    | `(…, 5, 5)`                 | Internal load balancer frontends other stamps call over the mesh |
| *reserved*          | /27 (32)   | .0.192    | `(…, 5, 6)`                 | Private Link Service NAT IPs (not created) |
| *spare*             | /27 (32)   | .0.224    | `(…, 5, 7)`                 | |
| `snet-aks-user`     | /24 (256)  | .1.0      | `(…, 2, 1)`                 | User node pools, ~250 nodes |
| `snet-pe`           | /24 (256)  | .2.0      | `(…, 2, 2)`                 | Private endpoints (Key Vault, Storage, ACR, …) |
| *reserved*          | /24 (256)  | .3.0      | `(…, 2, 3)`                 | App Gateway for Containers or a second user pool (not created) |

The node subnets are unique per stamp, which makes them the caller identity
for network policies in other stamps (`node_subnet_prefixes` output).

## Inside the hub /22

Carved automatically by `modules/hub` when the firewall is enabled:

| Subnet                        | CIDR (first /26s of the hub range) |
|-------------------------------|------------------------------------|
| AzureFirewallSubnet           | `cidrsubnet(hub, 4, 0)` → 10.x.0.0/26  |
| AzureFirewallManagementSubnet | `cidrsubnet(hub, 4, 1)` → 10.x.0.64/26 |

The rest of the /22 is spare for future hub services (Bastion, VPN gateway,
DNS Private Resolver, ...).

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
