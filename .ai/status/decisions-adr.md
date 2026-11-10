# Architectural Decision Records

Newest last. One section per decision; never delete - supersede.

## ADR-001: Compose AVM resource modules; do not use avm-ptn-aks-enterprise

2026-07-21 · Accepted

The official pattern module (v0.1.0, only release) hardcodes ~$1,700/mo
(Firewall Standard, ACR Premium, private cluster + UDR, D16ds_v5 system
pool), creates its own VNet with no existing-subnet input, and exports no
VNet ID - hub-spoke peering impossible, cost goals impossible. We compose
hubnetworking 0.13.2 / virtualnetwork 0.19.0 / managedcluster 0.6.7 /
containerregistry 0.5.1 / operationalinsights 0.5.1, pinned exactly.

## ADR-002: Classic terragrunt includes, not stacks

2026-07-21 · Accepted

`root.hcl` + `_envcommon` + deep-merge includes. The experimental
`terragrunt.stack.hcl` would shrink leaves further but is less universally
understood; this is a teaching repo. Revisit if the matrix grows.

## ADR-003: All real values via env vars; local-backend fallback

2026-07-21 · Accepted

Public repo → subscription/tenant/object IDs, storage names, and IPs live
only in `.env` (gitignored) / GitHub repo variables. When `TG_STATE_*` is
unset, root.hcl swaps the azurerm backend for a throwaway local backend -
this (not `init -backend=false`, which breaks terragrunt dependency output
fetching) is what makes the whole graph validate offline.

## ADR-004: Public API server + authorized IPs in dev; private only in prod

2026-07-21 · Accepted

Private clusters need a jumpbox/Bastion/VPN (~$140+/mo) to be usable.
Dev uses `api_server_authorized_ip_ranges` = TG_AUTHORIZED_IP instead.

## ADR-005: Deterministic firewall private IPs as constants

2026-07-21 · Accepted

Hub A's firewall routes need hub B's firewall IP and vice versa - a circular
dependency between the two hub states. Azure always assigns the firewall the
first host (.4) of AzureFirewallSubnet, which we always carve as the first
/26 of the hub /22, so leaf files hardcode `10.x.0.4`. Verified live: both
firewalls landed on the predicted IPs. Trade-off: if the carve ever changes,
update `firewall_route_entries` in the hub leaves.

## ADR-006: RBAC-only state storage (no shared keys)

2026-07-21 · Accepted

`use_azuread_auth = true` + `--allow-shared-key-access false`; humans and CI
get Storage Blob Data Contributor. No storage keys exist to leak.

## ADR-007: Cross-region transit via per-hub firewalls, not spoke peering

2026-07-21 · Accepted (user decision)

VNet peering is non-transitive; direct spoke↔spoke peering would work and
cost ~nothing but bypasses the hubs. Chosen: Firewall Basic per hub +
hub↔hub global peering + node-subnet UDR (10.0.0.0/8 → local FW) + per-hub
firewall routes to remote spokes. All behind `enable_firewall` so the repo
still has a cheap mode. Verified 2026-07-21 (see test-results).

## ADR-008: AVM quirks encoded in wrappers (learned the hard way)

2026-07-21 · Accepted

- hubnetworking dereferences `firewall.default_ip_configuration` and uses
  `firewall_policy.name` without guards; optional object attrs exist-as-null
  so its `try()` fallbacks never fire → wrapper passes all of them explicitly.
- managedcluster is azapi-based: `parent_id` (RG resource ID), not
  `resource_group_name`; kubelet identity output attr is `.objectId`.
- containerregistry defaults to Premium + zone redundancy → wrapper forces
  `zone_redundancy_enabled=false` for Basic.
- BYO-VNet AKS: control-plane identity needs Network Contributor on the
  spoke VNet (+ node route table) or internal LBs stay `<pending>`.

## ADR-009: AVNM global mesh as the second east-west path; per-env AVNM at subscription scope

2026-11-01 · Accepted

Adapting the "AKS Stamp Network Plan" (one AVNM at the top MG, pools
root→region→env, one global mesh per environment). This repo has one
subscription and independent dev/prod trees with separate state, so it runs
**one AVNM per environment, scoped to the subscription**, one IPAM pool per
region - same resources, same tag contract (`role=aks-stamp`, `env`, `unit`,
`stamp-id`), narrower scope. Membership is dynamic via an Azure Policy in
`Microsoft.Network.Data` mode: the platform state never references a spoke
(static members would be circular with the pool-ID dependency). Hubs stay
out of the mesh and keep plain hub↔spoke peering (no AVNM hub-and-spoke
config: already works, free). The mesh coexists with ADR-007's firewall
transit as an alternative, not a replacement: `enable_avnm` empties
`firewall_routed_cidrs` because a UDR overrides the connected-group route.
Off in dev (AVNM bills per managed VNet), on in prod (plan-only).

## ADR-010: Spokes are uniform /22 stamps; subnets carved via the AVM subnet submodule

2026-11-01 · Accepted

Every spoke VNet is a /22 (`stamp_prefix_length`) with a fixed relative
layout (system /25, ilb /27, user /24, pe /24; apiserver/pls/agc offsets
reserved), allocated by IPAM when `enable_avnm` or statically as the first
/22 of `region.hcl: stamp_pool_prefix` otherwise. The former spoke /16 is
now the pool (64 stamps). Subnet prefixes are `cidrsubnet()` of the VNet
module's `address_spaces[0]` output, which cannot feed the same module's
`subnets` input (cycle) - so subnets use
`avm-res-network-virtualnetwork//modules/subnet` separately. The submodule
README explicitly supports "IPAM VNet + traditional subnet" (answers the
source plan's open question). Node subnets are unique per stamp →
`node_subnet_prefixes` output is the caller identity for in-cluster policy.
Trade-off: switching a live spoke between modes recreates VNet + cluster.

## ADR-012: Landing-zone layout - subscription per role, management groups, one AVNM at the top MG

2026-11-01 · Accepted (supersedes the "per-env AVNM at subscription scope" half of ADR-009)

The enterprise plan's real scope costs nothing extra (MGs/subscriptions are
free; AVNM bills per managed VNet regardless of scope), so the repo now has
it: `management` (existing sub, holds state), `connectivity` (all hubs +
AVNM + IPAM), `dev`/`prod` (stamps) under `mg-<prefix>` → `-platform` /
`-landingzones` → `-<env>`. One `modules/platform-network` instance at
`live/platform/network`, scoped to the top MG, with /12 root pools per
region split into /16 env pools (nested IPAM pools), MG-scoped membership
policies, one mesh per env, and rule 200 derived from the other envs'
pools. Subscription placement is a path→env-var map in `live/root.hcl`
(hubs and platform → connectivity; stamps → `TG_SUBSCRIPTION_<ENV>`), with
`ARM_SUBSCRIPTION_ID` as the fallback so single-subscription use is
unchanged; `enable_management_groups = false` keeps the AVNM at
subscription scope for tenants where root elevation is impossible.
Subscriptions are created in the portal, not vended: the billing account is
MOSP (personal Pay-As-You-Go), which the subscription alias API does not
accept; a vending module would be dead code here. Renumbered so the pool
hierarchy is real: hubs 10.0/10.1.0.0/16 per region, stamp roots
10.16/10.32.0.0/12 (nothing was deployed, so free). Hub↔spoke peering
crosses subscriptions - fine because the AVM peering submodule uses full
resource IDs (azapi) for both directions.

## ADR-011: Cilium dataplane follows network_policy

2026-11-01 · Accepted

Azure rejects `networkPolicy=cilium` without `networkDataplane=cilium`; prod
(plan-only) had the former without the latter. The wrapper now derives
`network_dataplane` from `network_policy`, keeping one toggle in env.hcl.

## ADR-013: Features matured in a private deployment are back-ported here, scrubbed

2026-11-10 · Accepted

This example was adopted (copied, not referenced) into a private, real
deployment at commit `10a4010`, where ADR-014 onward were decided and
verified. Those changes are back-ported here as a single commit with every
real value replaced: domains → `example.com`, GitHub owners →
`your-org` / `<owner>/<repo>`, name prefix → `demo`, application
repositories → `app-a` / `app-b`, the laptop-cluster environment →
`local`. Anything that names a domain or turns on cost (public DNS, the
local cluster) is opt-in through an env var, so the defaults stay
template-safe. The private deployment's test evidence is not copied; the
evidence here (`.ai/test-results/`) is this repo's own.

## ADR-014: Prod applies only via the deploy workflow; dev should mirror prod's topology

2026-11-07 · Accepted (back-ported 2026-11-10)

Applies: dev may be applied locally after a reviewed plan; prod only via
`deploy.yml` (manual dispatch, main only, typed confirm string), each target
running in the GitHub Environment of the same name with a `main`-only
deployment branch policy. Required reviewers can be layered on where the
GitHub plan allows. For a real deployment, dev is the integration test bed
for everything prod relies on, so `enable_avnm = true` and
`network_policy = "cilium"` should be its deliberate defaults
(~$150/mo/region vs ~$75-100 without AVNM), with `enable_firewall` false
(east-west rides the mesh; north-south egress via the LB is fine in dev).
This repo's `live/dev/env.hcl` still carries both as `TEMP` markers from
plan 003 (backlog) so the cheapest configuration stays one edit away.
A deployment derived from this repo needs its own state storage account
(or `TG_STATE_CONTAINER`): state keys are unit paths and would collide.

## ADR-015: AVM modules consumed as git commit SHAs; lint toolchain pinned by checksum

2026-11-07 · Accepted

Every AVM module source is `git::https://github.com/Azure/terraform-azurerm-avm-*.git?ref=<40-char sha>`
with the tag in a trailing comment (CLAUDE.md §2). Tags are mutable, SHAs
are not; `terraform init` now needs git and GitHub access (CI has both).
Limitation: the AVM modules themselves still pull their internal helper
modules from the registry by version (`avm-utl-interfaces`, the
hubnetworking pattern's resource modules); that is upstream code we do not
rewrite. tflint 0.65.0 (+ azurerm ruleset 0.33.0), trivy 0.76.2 and
terraform-docs 0.24.0 are installed by `scripts/install-tools.sh` with
sha256 pins from each project's release checksum file, run by
`scripts/lint.sh` locally and in `ci.yml`; module READMEs are generated
and a stale README fails CI. checkov was not added: trivy covers the same
misconfiguration classes and adding a second Python scanner buys noise.

## ADR-016: Firewall egress as per-stamp UDR or AVNM routing (UseExisting); prod keeps loadBalancer until verified

2026-11-07 · Accepted (code only, unverified live)

`aks_outbound_type = "userDefinedRouting"` makes a stamp send 0.0.0.0/0 to
its hub firewall, and the hub adds the AKS required-egress rule collection
(FQDN tag `AzureKubernetesService`, 1194/9000 to `AzureCloud.<region>`,
NTP, registries). `enable_avnm_routing` moves the default route into an
AVNM routing configuration in `UseExisting` mode: AVNM writes the route into
each stamp's existing node route table, bound per env/region through a
regional network group (membership policy on tags + location) because the
next hop differs per region. Both default off everywhere, including prod,
until dev has verified the path with a firewall; the AKS egress rule set is
the one Microsoft documents but a Basic firewall has no FQDN *filtering*
of HTTP, so a live run must confirm nodes join. Alternatives rejected:
managedNATGateway (no inspection, and would need a NAT gateway per stamp);
AVNM `CreateNew` mode (AVNM-owned route tables would replace the module's
and lose the transit routes).

## ADR-017: Central private DNS per environment, linked from the consumers' state; external-dns via workload identity

2026-11-07 · Accepted (code only, unverified live)

One private DNS zone per environment (`svc.<env>.platform.internal`) in
`rg-dns-platform` (connectivity), created by platform-network. Hubs and
stamps link their own VNets to it *from their own state* by zone ID (azapi,
since the azurerm link resource cannot cross subscriptions), so adding a
stamp never writes to the platform state - the same rule as network-group
membership. Inside Azure no resolver is needed; `enable_dns_resolver` adds
a hub inbound endpoint for on-prem. external-dns gets a per-stamp
user-assigned identity (AVM) with a federated credential for
`system:serviceaccount:external-dns:external-dns`, Private DNS Zone
Contributor on the zone and Reader on the zone RG; this is also the
platform's workload-identity reference implementation. Per-environment
zones, not one tenant-wide zone, so environments cannot resolve each
other's services (matching the per-environment meshes).

## ADR-018: Additional stamps are folders; excluded until enabled

2026-11-07 · Accepted

`aks-spoke-2`, `aks-spoke-3`, ... under a region folder are full units; the
folder name's suffix is passed as `stamp_suffix` and lands on every resource
name and the `stamp-id` tag. Each extra unit carries an `exclude` block
gated on `env.hcl: enable_extra_stamps`, so the folder exists (and
validates) without `run --all` creating it. Chosen over a `stamps = N`
count in env.hcl because a unit per stamp keeps independent state, which is
what makes adding or destroying one safe.

## ADR-019: Public DNS as a platform-tier unit - one zone per cloud, one delegated child per environment

2026-11-07 · Accepted

`live/platform/dns` (connectivity subscription, `rg-dns-public`) creates
`azure.example.com` and `<env>.azure.example.com` for every entry
in `platform.hcl: environments`, with the NS delegation records in the
parent generated from each child's Azure-assigned name servers. The apex
`example.com` stays at the registrar; delegating the `azure` label is
the one manual step, done once with the `parent_name_servers` output. The
per-cloud parent (`azure.`, and e.g. `aws.` for another cloud) keeps each cloud's
automation confined to its own subtree, and per-environment children let
each stamp's external-dns identity hold DNS Zone Contributor on exactly its
environment's zone. It is a platform unit, not an environment unit,
because every environment depends on it - production-grade from day one
even while only dev exists; In this repo the hierarchy is off until
`TG_PUBLIC_DNS_PARENT_ZONE` names a zone you own (2026-11-10), so the
template never creates a zone for a domain nobody controls. Every stamp depends on it (mocked offline), the same
contract pattern as `platform/network`. Alternative rejected: zones in the
environment subscriptions - would need the parent's NS records to be
written across states and would make the parent depend on its children.

## ADR-020: Managed Prometheus is its own toggle; onboard_monitoring follows it

2026-11-07 · Accepted (found by the first real prod plan)

The AVM managedcluster module's `onboard_monitoring` instantiates a
monitoring submodule that requires `prometheus_workspace_id`; the example
set it from `enable_container_insights` with no workspace, so prod had
never been plannable. Now `enable_managed_prometheus` creates an Azure
Monitor workspace (plain `azurerm_monitor_workspace`: no AVM module exists
for it as of 2026-11-07) and drives `onboard_monitoring`; the OMS agent
addon alone still follows `enable_container_insights`. Prod on, dev off.

## ADR-021: External environments get a public DNS zone and nothing else

2026-11-07 · Accepted

`platform.hcl: external_environments` lists environments that run outside
Azure (e.g. `local`, a laptop Rancher Desktop / k3s cluster where Argo
CD app deployments are developed; opt-in with `TG_ENABLE_LOCAL_CLUSTER`). They are fed only to `live/platform/dns`,
so they get `<name>.azure.example.com` delegated like dev and prod but
no management group, hub, IPAM pool or stamp - putting them in
`environments` would have required a `live/<name>` tree and created an
empty landing-zone management group. Credentials for a local cluster's
external-dns are out of scope and never live in this repo.

## ADR-022: Network Watcher auto-creation is disabled per subscription

**Context.** The 2026-11-02 hub/spoke applies (`.ai/test-results/2026-11-02-*.md`) left
`NetworkWatcherRG/NetworkWatcher_{westus3,eastus2}` in connectivity and dev.
The activity log shows a Microsoft service principal writing each watcher
within seconds of the first VNet in that region; no module creates one and
none was ever in state, so `terragrunt destroy` could not remove them. They
cost nothing (no flow logs, connection monitors or diagnostics exist; Cost
Management shows no Network Watcher meter), but they are unmanaged drift
and confuse "is the subscription empty?" checks after a destroy.

**Decision.** `bootstrap/register-providers.sh` registers the
`Microsoft.Network/DisableNetworkWatcherAutocreation` feature in every
subscription and re-registers `Microsoft.Network` once it is `Registered`
(the flag only applies after that). The four orphans were deleted by hand
on 2026-11-07. If a watcher is ever needed (flow logs, connection
troubleshoot, NSG diagnostics) a module creates it explicitly behind an
off-by-default toggle so it lives and dies with Terraform state.

**Consequences.** Subscriptions return to exactly their pre-apply contents
after a destroy. Network Watcher features are unavailable in a region until
a toggle creates the watcher. `SKIP_NETWORK_WATCHER_OPT_OUT=1` restores
Azure's default for anyone who prefers it.

## ADR-023: External environments get a Terraform-managed, zone-scoped service principal

2026-11-08 · Accepted · supersedes the last sentence of ADR-021

**Context.** `local` runs external-dns and cert-manager (DNS-01) against
`local.azure.example.com`. A cluster outside Azure has no managed
identity, and neither controller supports certificate credentials, so the
choices were Azure Arc-enabled Kubernetes (Azure-hosted OIDC issuer →
workload identity, tier 1 of docs/identity.md) or a client secret (tier 4).
ADR-021 had left the credential out of scope for this repo; the manifests
repo had an `az` CLI script creating it by hand.

**Decision.** Arc is declined for the laptop cluster (agents, apiserver
flag, quarterly key rotation, re-connect after every factory reset - for a
development zone). Instead `modules/public-dns-principals`, applied from
`live/platform/dns-principals` (connectivity subscription, depends on
`platform/dns`), creates one Entra app + service principal `sp-dns-<env>`
per `platform.hcl: external_environments`, with DNS Zone Contributor on
that environment's zone and Reader on `rg-dns-public`, nothing else. The
client secret lifetime is the Entra portal maximum, 24 months
(`dns_principal_secret_days = 730`, chosen over frequent rotation; a
tenant app management policy may cap it lower); `time_rotating` rotates it on
the first apply after expiry and `secret_end_dates` is an output. The
secret exists only in state and in the cluster: the manifests repo's
`scripts/azure-dns-local-credentials.sh` reads `terragrunt output -json`
and writes the two cluster secrets. The deploy pipeline identity is an
owner of the apps and both pipeline identities get Graph app roles
(`Application.Read.All`; deploy also `Application.ReadWrite.OwnedBy`),
granted in `bootstrap/setup-oidc.sh`.

**Consequences.** The first Entra resources in this repo (azuread
provider). A new local environment = one entry in `external_environments`
→ zone + principal in one platform apply. If a local cluster ever needs
Key Vault or ACR access, revisit Arc rather than widening the principal.

## ADR-024: A local cluster's secrets come from an Azure Key Vault in the dev subscription

2026-11-08 · Accepted

**Context.** `local` needs more than DNS credentials now: a Google OAuth
client for the Gateway login and Argo CD SSO, cookie secrets, and the DNS
principal's secret itself was being copied by a script. Secrets created by
hand on a cluster are invisible to Git and to rotation.

**Decision.** `modules/local-cluster`, applied from
`live/dev/local/local-cluster` (the dev subscription hosts everything
local owns in Azure), creates `rg-demo-local`, an RBAC-mode
Key Vault `kv-demo-local` (AVM keyvault v0.13.0; purge protection
off so a dev vault can be destroyed; public endpoint, since the laptop's IP
changes) and a second principal `sp-eso-local` via the new
`modules/service-principal`, with Key Vault Secrets User on that vault only.
Terraform writes the secrets it knows (DNS principal credentials from
`platform/dns-principals`, a generated oauth2-proxy cookie secret); the
Google OAuth client secrets are created by Terraform as placeholders
(`REPLACE_ME`) with `ignore_changes = [value]`, so the vault's contents are
declared in code while the real values are set once by an operator with
`az keyvault secret set` and never overwritten (chosen over leaving
them undeclared). External Secrets Operator syncs the
vault into the cluster; the ESO credential is the only secret an operator
ever loads (`bootstrap-external-secrets.sh` in the manifests repo). The
applying principal and the deploy pipeline get Key Vault Secrets Officer.

**Consequences.** One principal per component (`sp-dns`, `sp-eso`), as on
AKS. A second local environment is one `external_environments` entry plus
one `live/<sub>/<name>/local-cluster` folder. `public-dns-principals` should
be moved onto `modules/service-principal` (backlog). If a local cluster ever
needs ACR or more, revisit Arc instead of a third principal.

## ADR-025: One workload identity per component per stamp; one Key Vault per environment

2026-11-08 · Accepted

**Context.** `modules/aks-spoke` had a hand-written external-dns identity;
cert-manager and External Secrets needed the same shape (docs/identity.md
§2: one identity per Kubernetes service account per cluster, never shared
across environments), and External Secrets needs a vault to read. The
local cluster had just grown a vault inside `modules/local-cluster`.

**Decision.** `modules/workload-identity` (AVM user-assigned identity +
one federated credential for `namespace/name` + a map of narrow role
assignments) is the tier-1 building block, mirroring
`modules/service-principal` for tier 4. `aks-spoke/identity.tf` instantiates
it three times behind `enable_*_identity` toggles: `id-external-dns-<stamp>`
(zone contributor + RG reader), `id-cert-manager-<stamp>` (public zone
contributor), `id-external-secrets-<stamp>` (Key Vault Secrets User on the
environment vault). `modules/key-vault` is extracted from local-cluster:
one RBAC vault per environment (`kv-<prefix>-<env>`, applied from
`live/<env>/keyvault` in the environment's first region, resource group
`rg-<prefix>-<env>-secrets`), holding managed, generated and
operator-placeholder secrets; readers grant themselves (the stamps), writers
are the applying principal and the pipeline identities. local-cluster and
public-dns-principals were moved onto the new building blocks with `moved`
blocks; the real plans show only moves. Prod's vault has purge protection
and 90-day soft delete; dev's is destroyable.

**Consequences.** Stamps depend on `live/<env>/keyvault` (mocked offline).
Modules that call siblings are referenced as `modules//<name>`. Manifests
overlays for AKS use three client IDs per environment instead of one. The
vaults are public-endpoint + RBAC for now; private endpoints are backlog.

## ADR-026: An external environment's images live in a Basic ACR; GitHub pushes through OIDC, the cluster pulls with a scoped token

2026-11-08 · Accepted · qualifies the closing sentence of ADR-024

**Context.** `local` is about to run the first application image
(`your-org/app-a`, a sample web app). Its container image needs a
registry that GitHub Actions can push to without a stored secret and that
the laptop cluster can pull from. ADR-024 said "if a local cluster ever
needs ACR, revisit Arc rather than adding a third principal"; GHCR with a
personal access token was the interim idea.

**Decision.** `modules/local-cluster` gains `enable_acr` (on for
local): an `azurerm_container_registry` `cr<prefix><env>`
(`crdemolocal`) in the environment's resource group, **Basic**
SKU, the cheapest tier (~$5/month, 10 GB), admin user and anonymous pull
off. Two sides, neither a client secret:

* **Push: tier 2, no new principal type.** `modules/github-actions-identity`
  (the GitHub twin of `modules/workload-identity`: AVM user-assigned
  identity + one federated credential per subject + narrow roles) creates
  `id-gh-<repo>-<env>` per `acr_push_repositories` entry with **AcrPush on
  that registry only**. GitHub's immutable subject prefix
  (`repo:<owner>@<id>/<repo>@<id>`) is an identifier like any other and
  comes in through `TG_OIDC_SUBJECT_PREFIX_<REPO>` (`.env`, repository
  variable), never Git. The source repo gets `AZURE_CLIENT_ID`,
  `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `ACR_LOGIN_SERVER` variables
  and logs in with `azure/login` + `az acr login`.
* **Pull: an ACR repository-scoped token, not a third service principal.**
  Entra RBAC on ACR cannot be narrowed below the registry, and the cluster
  has no identity Entra can federate (ADR-023). ACR tokens are native to
  every tier (Basic allows 100), read-only here and scoped to the listed
  repositories (`acr_pull_repositories`, default = the push keys). The
  password follows the service-principal rotation shape (`time_rotating`,
  `secret_rotation_days`) and Terraform writes `acr-login-server`,
  `acr-pull-username`, `acr-pull-password` into the environment vault;
  External Secrets templates them into the cluster's `imagePullSecret`.
  The GHCR pull-token placeholders are therefore unnecessary.

Arc stays declined (ADR-023); this adds no Entra principal for the cluster.

**Consequences.** Registry cost ~$5/month is the first real line item of
the local footprint. A second image = one key in
`acr_push_repositories` (+ its prefix variable) and a line in the manifests.
On AKS the pattern is unchanged: the kubelet identity pulls with AcrPull
(docs/identity.md §4). `modules/github-actions-identity` is also the
building block for any future repo that must reach Azure from Actions.
The raw `azurerm_container_registry` resource is used rather than the AVM
registry module (which aks-spoke uses) because Basic needs none of the
module's surface (zone redundancy, network rules, private endpoints) - a
deliberate exception to the AVM-first guideline, revisit if the SKU grows.
