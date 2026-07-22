# IP address plan

Every VNet in every environment/region gets a globally non-overlapping slice
of `10.0.0.0/8`, so any future peering (hub↔hub for global connectivity,
spoke↔spoke, VPN to on-prem) is possible without renumbering.

Scheme: second octet = `env_base + region_index * 10`, where dev starts at 10,
prod at 110, and regions are numbered westus3=0, eastus2=1. The hub takes the
`.X0.0.0/22`, the spoke takes the whole `.X1.0.0/16`.

| Env  | Region  | Hub VNet (/22) | Spoke VNet (/16) | AKS nodes (/20) | Private endpoints (/24) |
|------|---------|----------------|------------------|-----------------|-------------------------|
| dev  | westus3 | 10.10.0.0/22   | 10.11.0.0/16     | 10.11.0.0/20    | 10.11.16.0/24           |
| dev  | eastus2 | 10.20.0.0/22   | 10.21.0.0/16     | 10.21.0.0/20    | 10.21.16.0/24           |
| prod | westus3 | 10.110.0.0/22  | 10.111.0.0/16    | 10.111.0.0/20   | 10.111.16.0/24          |
| prod | eastus2 | 10.120.0.0/22  | 10.121.0.0/16    | 10.121.0.0/20   | 10.121.16.0/24          |

These values live in each `live/<env>/<region>/region.hcl`.

## Inside the hub /22

Carved automatically by `modules/hub` when the firewall is enabled:

| Subnet                        | CIDR (first /26s of the hub range) |
|-------------------------------|------------------------------------|
| AzureFirewallSubnet           | `cidrsubnet(hub, 4, 0)` → 10.x.0.0/26  |
| AzureFirewallManagementSubnet | `cidrsubnet(hub, 4, 1)` → 10.x.0.64/26 |

The rest of the /22 is spare for future hub services (Bastion, VPN gateway,
private DNS resolvers, ...).

## Cluster-internal ranges (identical in every cluster)

AKS runs Azure CNI in **overlay** mode: pod IPs are NAT'd behind the node IPs
and are not routable outside the cluster. They only need to avoid overlapping
the cluster's own VNet and its *directly peered* VNets - and since a spoke
only peers with its regional hub (10.x/8 ranges above), the same private
ranges are safely reused everywhere:

| Purpose        | CIDR             |
|----------------|------------------|
| Pods (overlay) | 192.168.0.0/16   |
| Services       | 172.20.0.0/16    |
| Cluster DNS    | 172.20.0.10      |

**Constraint to remember:** if you ever peer a spoke to anything else, nothing
in `10.0.0.0/8` may be reused (guaranteed by the table above), and the peered
network must not use `192.168.0.0/16` or `172.20.0.0/16`.

## AKS node subnet sizing

A /20 (4,091 usable IPs) is generous for overlay mode, where each node only
consumes one IP regardless of pod count. It leaves room to switch to flat
Azure CNI (IP per pod) later without re-addressing.
