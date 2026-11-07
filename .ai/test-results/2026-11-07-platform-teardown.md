# 2026-11-07 - platform teardown (end of plans 003/004 test)

- **Command**: `cd live/platform && terragrunt run --all --non-interactive -- destroy`
- **Result**: ✅ exit 0, 35 resources destroyed, zero errors
- **Precondition**: `live/dev` already destroyed 2026-11-02 (dev subscription
  held only `NetworkWatcherRG`).

## Destroy plan (reviewed first)

| Unit              | Plan                                |
|-------------------|-------------------------------------|
| network           | 0 to add, 0 to change, 29 to destroy |
| management-groups | 0 to add, 0 to change, 6 to destroy  |

Network unit: resource group, network manager, 2 root + 4 env IPAM pools,
2 network groups, 2 policy definitions + 2 MG policy assignments, 2 mesh
connectivity configurations, 1 security admin configuration, 2 rule
collections, 6 admin rules, 4 deployments (connectivity + security admin ×
2 regions). Management-groups unit: top, platform, landing-zones, dev, prod
+ the `Microsoft.Network` MG provider registration action.

## Destroy

Reverse dependency order held: network unit first (deployments undeployed,
then rules/configs/groups/pools/manager/RG, policy assignments then
definitions), then the management groups (subscriptions detached by the
provider before each group was deleted).

```
[network]           Destroy complete! Resources: 29 destroyed.
[management-groups] Destroy complete! Resources: 6 destroyed.
```

## Verification

- `az account management-group list` → only the Tenant Root Group.
- Resource Graph `resourcecontainers`: all four subscriptions report the
  Tenant Root Group as their only management-group ancestor.
- Resource Graph `microsoft.network/networkmanagers` tenant-wide → 0.
- Resource Graph `policyresources` named `avnm*` / `ng-stamps*` → 0.
- Connectivity subscription resource groups: `NetworkWatcherRG` and
  `azure-signup-rg` only (Azure-created, free). Dev: `NetworkWatcherRG`.
- Kept on purpose: `rg-tfstate-dev` + state storage in the management
  subscription (created 2026-07-22, predates this test; the six state blobs
  are now empty states); the four subscriptions themselves (portal-created,
  cancel in the portal if not rebuilding); Owner + User Access Administrator
  at `/` for the signed-in user (manual removal, see ACTIVE_SESSION.md).
