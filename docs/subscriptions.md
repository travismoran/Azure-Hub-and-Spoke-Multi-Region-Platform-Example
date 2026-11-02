# Subscriptions and management groups

The platform is laid out the way an Azure landing zone is: one subscription
per role, grouped under a small management-group hierarchy, with the
tenant-wide pieces (management groups, the Azure Virtual Network Manager)
applied once from `live/platform` and the environments applied from
`live/<env>`. None of this costs anything by itself - management groups and
subscriptions are free; only resources inside them bill.

```
Tenant Root Group
└── mg-<prefix>                      ← AVNM scope; network-group policies assigned here
    ├── mg-<prefix>-platform
    │   ├── management subscription  ← terraform state storage (bootstrap/)
    │   └── connectivity subscription← every hub VNet + firewall, AVNM, IPAM pools
    └── mg-<prefix>-landingzones
        ├── mg-<prefix>-dev          ← dev subscription: dev AKS stamps
        └── mg-<prefix>-prod         ← prod subscription: prod AKS stamps
```

`<prefix>` is `TG_NAME_PREFIX` (`demo` by default; management group IDs are
tenant-unique, so forks in a shared tenant change it).

## Which unit goes where

`live/root.hcl` decides the subscription for every unit from its path, and
generates the provider block accordingly. There is nothing to configure per
unit:

| Unit (path) | Subscription | Env var |
|---|---|---|
| `platform/management-groups` | management (tenant-scoped resources; any subscription works) | `TG_SUBSCRIPTION_MANAGEMENT` |
| `platform/network` | connectivity | `TG_SUBSCRIPTION_CONNECTIVITY` |
| `<env>/<region>/hub` | connectivity | `TG_SUBSCRIPTION_CONNECTIVITY` |
| `<env>/<region>/aks-spoke` | that environment | `TG_SUBSCRIPTION_<ENV>` |
| terraform state (all units) | management | `TG_SUBSCRIPTION_MANAGEMENT` + `TG_STATE_*` |

Every variable that is *unset* falls back to `ARM_SUBSCRIPTION_ID`. A
variable that is set but **empty** (`TG_SUBSCRIPTION_PROD=""`) means "no
such subscription yet": the environment's management group is created
empty, and a plan of that environment's stamps fails on a missing
subscription rather than quietly landing somewhere else.

Hub↔spoke peering therefore crosses subscriptions. The spoke module creates
both directions with full resource IDs (azapi, `parent_id` = the remote
VNet), which works across subscriptions as long as the deploying identity
has Network Contributor on both sides - Owner on each subscription, in this
example.

## Single-subscription mode

Set only `ARM_SUBSCRIPTION_ID` and leave every `TG_SUBSCRIPTION_*` unset:
all units deploy into that one subscription. Optionally set
`enable_management_groups = false` in `live/platform/platform.hcl` to skip
the hierarchy entirely; the network platform then scopes the AVNM and its
membership policies to the subscription instead of the management group.
Everything else is identical. This is the mode the repo ran in before the
multi-subscription layout and remains fully supported.

## One-time setup

1. **Create the subscriptions** in the portal (Subscriptions → Add), one
   per role: `connectivity`, `dev`, later `prod`. Reuse the existing one as
   `management` - it already holds the state storage account. Why the
   portal: creating subscriptions with Terraform (the subscription alias
   API, `avm-ptn-alz-sub-vending`) needs an Enterprise Agreement, Microsoft
   Customer Agreement or Partner Agreement billing account. A personal
   Pay-As-You-Go account (`agreementType: MicrosoftOnlineServicesProgram`
   in `az billing account list`) has no billing scope the API accepts, so
   subscriptions are created by hand and referenced by ID. New
   Pay-As-You-Go subscriptions are rate-limited to a few per day.

2. **Put the IDs in `.env`** (never in the repo):

   ```bash
   export TG_SUBSCRIPTION_MANAGEMENT="$ARM_SUBSCRIPTION_ID"
   export TG_SUBSCRIPTION_CONNECTIVITY="$(az account show -s connectivity --query id -o tsv)"
   export TG_SUBSCRIPTION_DEV="$(az account show -s dev --query id -o tsv)"
   export TG_SUBSCRIPTION_PROD=""   # until it exists
   ```

3. **Register resource providers** in every subscription (the provider
   config sets `resource_provider_registrations = "none"`):

   ```bash
   source .env && ./bootstrap/register-providers.sh
   ```

4. **Tenant-root access, once.** Creating management groups under the
   Tenant Root Group and moving subscriptions into them needs rights at the
   root scope, which nobody has by default - not even a Global
   Administrator. The documented path is to elevate, grant yourself a role
   at `/`, and sign in again:

   ```bash
   az rest --method post --url "/providers/Microsoft.Authorization/elevateAccess?api-version=2016-07-01"
   az logout && az login   # the elevated role is only in a NEW token
   az role assignment create --role Owner --scope / \
     --assignee-object-id "$(az ad signed-in-user show --query id -o tsv)" \
     --assignee-principal-type User
   az logout && az login   # same again for the Owner role
   ```

   Running the role assignment with the pre-elevation token fails with
   `AuthorizationFailed ... roleAssignments/write over scope
   /providers/Microsoft.Authorization/roleAssignments/...` - sign in again
   and retry.

   Owner at `/` is broad; after the first apply it can be reduced to
   `Management Group Contributor` at `/` plus Owner on `mg-<prefix>` (the
   creator of a management group is its Owner), or removed and re-elevated
   when the hierarchy changes.

5. **Apply the platform, then an environment:**

   ```bash
   cd live/platform && terragrunt run --all -- apply   # management groups → network platform
   cd ../dev        && terragrunt run --all -- apply   # hubs → stamps
   ```

   The platform unit also registers `Microsoft.Network` on the top
   management group (an AVNM-at-management-group prerequisite; done with an
   `azapi_resource_action` in `modules/management-groups`).

## Adding an environment or subscription later

- A new subscription for an existing environment (`prod` tomorrow): set
  `TG_SUBSCRIPTION_PROD`, re-run `bootstrap/register-providers.sh`, and
  apply `live/platform/management-groups` - the subscription moves under
  `mg-<prefix>-prod`. Nothing else changes.
- A new environment: add it to `environments` in
  `live/platform/platform.hcl`, create `live/<env>/env.hcl` and its region
  folders, add `TG_SUBSCRIPTION_<ENV>`. The management group, the IPAM
  pools (if `enable_avnm`), the network group, the mesh and the security
  admin rules for it all follow from those files.

## Deploying identity, summarised

| Scope | Role | Why |
|---|---|---|
| `/` (tenant root) | Owner (or Management Group Contributor) | create management groups, move subscriptions |
| each subscription | Owner | resources, RBAC assignments, cross-subscription peering |
| `mg-<prefix>` | Resource Policy Contributor (in Owner) | membership policy definitions + assignments |
| IPAM pools | IPAM Pool User (in Contributor) | stamp VNets allocate from the pools |
| state storage account | Storage Blob Data Contributor | terraform backend (Entra auth, no keys) |
