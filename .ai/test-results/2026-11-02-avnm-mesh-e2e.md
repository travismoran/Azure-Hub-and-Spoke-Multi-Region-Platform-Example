# 2026-11-02 - plan 003 live verification: IPAM stamps + global mesh + policy (dev, cross-subscription)

Dev applied from `live/dev` with `enable_avnm = true` and `network_policy =
"cilium"` (both TEMP in env.hcl), hubs in the connectivity subscription,
stamps in the dev subscription, platform at `live/platform` (applied
earlier the same day). All IDs withheld.

## Results

| # | Check (plan 003 step 5) | Result |
|---|---|---|
| a | AKS creation with IPAM-allocated ("known after apply") subnet IDs | ✅ Both clusters created; plan showed `ipamPoolPrefixAllocations: numberOfIpAddresses=1024` from `ipam-<region>-dev`; VNets came out 10.16.0.0/22 (wus3) and 10.32.0.0/22 (eus2), subnets exactly at the fixed layout (system /25 .0.0, ilb /27 .0.160, user /24 .1.0, pe /24 .2.0). Activity log: `ipamPools/allocateResourcePrefixes` + `associateResourcesToPool` Succeeded once per stamp. |
| b | VNets join `ng-stamps-dev` by tag through the MG-scoped policy | ✅ Membership appeared ~35 min after VNet creation (Resource Graph `networkgroupmemberships`); both VNets then listed Mesh/isGlobal=true and the 3 security admin rules as effective. |
| c | Mesh commit in both regions | ✅ Connectivity commits `Deployed` in westus3 + eastus2 (dev + prod configs in each). |
| d | Cross-region pod → ILB over the mesh, NO firewalls, NO 10/8 UDR | ✅ curl from a wus3 pod to the eus2 internal LB 10.32.0.164:8080 (snet-ilb, externalTrafficPolicy Local): HTTP 200 in ~0.1 s. Provider saw the source as the wus3 node IP 10.16.0.4 (caller identity preserved). Cross-subscription hub↔spoke peering created both ways by the spoke. |
| e | Rule 300 blocks Internet on 22 | ✅ A public LB service exposing 22 and 80: port 80 HTTP 200 from the Internet, port 22 timeout. AKS had opened both ports in the node NSG (`k8s-azure-lb_allow_... 22,80 from Internet`), so the drop is the security admin rule. |
| f | `node_subnet_prefixes` → CiliumNetworkPolicy `fromCIDR` | ✅ Output of the wus3 stamp `["10.16.0.0/25","10.16.1.0/24"]`. Policy on the eus2 provider admitting those: HTTP 200. Policy admitting only 10.17.0.0/16 (prod pool): timeout. Restored: HTTP 200. |

Not captured: the node's effective route table (ConnectedGroup next hop) -
the CLI cannot read VMSS NIC effective routes directly; functional proof
above stands (no hub firewall exists and no UDR is attached).

Node sizes: `Standard_D2s_v6` (one system node per cluster). Dev plan after
the out-of-band `az aks update --api-server-authorized-ip-ranges`: no
changes in all 4 units (.env `TG_AUTHORIZED_IP` refreshed first).

## Fixes found only by this live run (all committed on feat/avnm-ipam-mesh)

1. `module.spoke_vnet.address_spaces` is a `set(string)`: `[0]` fails at
   plan time → `one()`.
2. Terraform drops null-valued outputs from state: with the firewall off
   the hub has no `firewall_private_ip` output → `try(..., null)` in
   `_envcommon/aks-spoke.hcl`.
3. Security admin rule priorities must be unique across the whole
   configuration, not per collection → per-environment offset.
4. New Pay-As-You-Go subscriptions: `Standard_B2ms` not offered, no AMD
   sizes in eastus2, zero quota for Bsv2/Dsv5 families → `Standard_D2s_v6`
   (10 vCPU quota per region, 3 spot vCPU).
5. Procedure: `TG_AUTHORIZED_IP` goes stale; refresh before `kubectl`.

## Cost while this stays up

~$150/mo: 2× D2s_v6 (~$70 each), 2 managed VNets in AVNM (~$0.10/hr each
≈ $146/mo on the published per-VNet meter - check the bill), 2 ACR Basic,
2 LB public IPs. Tear down with `cd live/dev && terragrunt run --all --
destroy` (platform stays, $0).
