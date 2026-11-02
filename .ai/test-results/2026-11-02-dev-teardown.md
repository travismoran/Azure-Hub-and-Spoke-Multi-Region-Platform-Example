# 2026-11-02 - dev teardown (after plan 003 live verification)

- **Command**: `cd live/dev && terragrunt run --all --non-interactive -- destroy`
- **Result**: ✅ exit 0, 46 resources destroyed, zero errors

## Destroy plan (reviewed first)

`terragrunt run --all -- plan -destroy` from `live/dev`:

| Unit              | Plan                               |
|-------------------|------------------------------------|
| westus3/aks-spoke | 0 to add, 0 to change, 20 to destroy |
| eastus2/aks-spoke | 0 to add, 0 to change, 20 to destroy |
| eastus2/hub       | 0 to add, 0 to change, 4 to destroy  |
| westus3/hub       | 0 to add, 0 to change, 2 to destroy  |

`live/platform/network` is an external dependency of the spokes and was
not in the destroy graph, as intended.

## Destroy

Reverse dependency order held: both spokes first (AKS, ACR, Log Analytics,
stamp VNet + subnets, RBAC), then the eus2 hub, then the wus3 hub.
Wall clock ~12 minutes.

```
[westus3/aks-spoke] Destroy complete! Resources: 20 destroyed.
[eastus2/aks-spoke] Destroy complete! Resources: 20 destroyed.
[eastus2/hub]       Destroy complete! Resources: 4 destroyed.
[westus3/hub]       Destroy complete! Resources: 2 destroyed.
```

## Orphan check

- Dev subscription resource groups: only `NetworkWatcherRG` (Azure-created,
  free).
- Connectivity subscription resource groups: `rg-avnm-platform` (the
  platform layer, kept), `NetworkWatcherRG`, `azure-signup-rg`
  (`Microsoft.BillingBenefits/freeServices` marker from subscription
  sign-up). Both free.
- Resource Graph over both subscriptions excluding `rg-avnm-platform`:
  4 network watchers + 1 free-services marker, nothing else.
- IPAM: `ipam-wus3-dev` and `ipam-eus2-dev` `getPoolUsage` →
  `allocatedAddressPrefixes: []`, 0 allocated IPs (the /22 stamps were
  released with the VNets).
- Network groups: `networkgroupmemberships` count 0.
- State storage (`rg-tfstate-dev`, management subscription) kept.

## Stale local artifacts

`~/.kube/aks-demo-dev-{wus3,eus2}.yaml` now point at deleted clusters;
regenerate with `az aks get-credentials --file ...` after a re-apply.
