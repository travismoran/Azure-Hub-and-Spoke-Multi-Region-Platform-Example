# Cost model

The whole point of this wrapper: the official `avm-ptn-aks-enterprise`
pattern hardcodes ~$1,700+/month of resources per cluster. Here, every
expensive feature is a toggle in `live/<env>/env.hcl`, and the dev defaults
are the cheapest configuration that still demonstrates a real hub-and-spoke
AKS platform.

Approximate US-region list prices as of mid-2026 - always check the
[Azure pricing calculator](https://azure.microsoft.com/pricing/calculator/)
for current numbers.

## Per region: dev defaults vs prod (all toggles on)

| Component | dev default | ~$/mo | prod setting | ~$/mo |
|---|---|---|---|---|
| AKS control plane | Free tier | 0 | Standard tier (SLA) | 73 |
| System node pool | 1× B2ms (burstable) | 60 | 3× D4ds_v5, zoned | 620 |
| User node pool | 0-2× D2as_v5 **Spot** (scales from 0) | 0-30 | 2-6× D4as_v5 on-demand | 280+ |
| Egress | AKS standard LB + 1 public IP | ~8 | Azure Firewall Standard + UDR | 912+ |
| Hub firewall (transit demo)* | Firewall Basic, `enable_firewall = true` | ~300 | (included above) | - |
| Network platform (AVNM + IPAM mesh)** | off | 0 | on, 1 managed VNet/region | ~73 + IPAM |
| Container registry | ACR Basic | 5 | ACR Premium | 50 |
| Log Analytics | off | 0 | on, ~10 GB/day | ~830 |
| Container insights | off | 0 | on | (in LAW ingest) |
| Defender for Containers | off | 0 | on (~$7/vCPU) | ~250 |
| Azure Policy addon | off | 0 | on | 0 |
| AVM telemetry | off | 0 | off | 0 |
| **Total** | | **~$75-100** | | **~$3,000+** |

\* Off by default (`enable_firewall = false` in `live/dev/env.hcl`) for the
~$75-100/mo floor. Flip to `true` to enable cross-region hub-to-hub transit
(see architecture.md) - UDRs, firewall routes, and transit rules activate
automatically. Verified end-to-end 2026-07-21.

\** Off by default (`enable_avnm = false`). AVNM bills ~$0.10/hr per
*managed* VNet - one that has a deployed configuration, i.e. each stamp VNet
in the mesh, not the hubs - plus a small fee per active IP in an IPAM pool
(every node NIC). The AVNM instance, empty pools, management groups and
extra subscriptions cost nothing, so the landing-zone layout
(docs/subscriptions.md) adds no fixed cost. Confirm current rates on the
pricing page; the figures above are the published model, not a quote. See
docs/network-platform.md.

Multiply by regions you actually apply. The repo defines dev+prod × 2 regions,
but nothing forces you to apply more than `dev/westus3`.

## Where the money hides

- **Azure Firewall** is the single biggest line item: ~$300/mo (Basic) to
  ~$912/mo (Standard) *before* data processing charges. Dev uses plain
  `loadBalancer` egress instead (`enable_firewall = false`,
  `outbound_type = "loadBalancer"`).
- **AVNM** is cheap per VNet but is a per-VNet meter that never sleeps, and
  it replaces the firewall only for east-west traffic. In dev, isolated
  regions (both toggles off) are the floor; one or the other when you need
  cross-region cluster-to-cluster.
- **Log Analytics ingestion** (~$2.76/GB) balloons with container insights on
  a busy cluster. That's why `enable_log_analytics`,
  `enable_container_insights`, and `enable_defender` all default to off.
- **Private clusters** are not directly expensive, but reaching them is: a
  jumpbox, Bastion (~$140/mo), or VPN. Dev uses a public API server restricted
  to your IP (`TG_AUTHORIZED_IP`) instead.
- **Node pools**: burstable B-series for the system pool and Spot for user
  pools cut compute cost 60-90%. Spot nodes can be evicted at any time - never
  put system components on them.

## Cheapskate tips while developing

- `az aks stop --name <cluster> --resource-group <rg>` deallocates all node
  pools overnight; `az aks start` brings the cluster back.
- The Spot user pool autoscales from **zero** - an idle dev cluster runs on a
  single B2ms.
- `terragrunt run --all destroy` in `live/dev/<region>` tears everything down;
  state, being external, survives.
