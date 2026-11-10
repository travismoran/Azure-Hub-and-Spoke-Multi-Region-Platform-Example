# Identity pattern: how workloads, clusters and pipelines authenticate to Azure

One rule for everything in this platform: **no long-lived secrets inside Azure**. Every principal
that talks to Azure gets a token by proving who it is to Entra ID (managed identity, or a
federated token from a trusted issuer), and holds exactly the role it needs on exactly the
resource it needs. The one documented exception is a cluster that runs outside Azure (section 5).
This document is the pattern; `modules/aks-spoke/identity.tf`, `modules/public-dns-principals`
and `bootstrap/` implement it.

Sources: Microsoft Learn on [AKS workload identity](https://learn.microsoft.com/azure/aks/workload-identity-overview),
[federation considerations](https://learn.microsoft.com/entra/workload-id/workload-identity-federation-considerations),
[managed identity best practices](https://learn.microsoft.com/entra/identity/managed-identities-azure-resources/managed-identity-best-practice-recommendations),
[securing workload identities](https://learn.microsoft.com/entra/architecture/secure-service-accounts),
[app registration security](https://learn.microsoft.com/entra/identity-platform/security-best-practices-for-app-registration),
[Arc-enabled Kubernetes workload identity](https://learn.microsoft.com/azure/azure-arc/kubernetes/workload-identity),
and the CAF [identity design area](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/design-area/identity-access-landing-zones). Checked 2026-11-07; decision on local clusters 2026-11-08.

## 1. Credential ladder

Microsoft's stated order of preference, which we adopt as policy:

| tier | credential | use here |
|---|---|---|
| 1 | **Managed identity** (user-assigned) with **workload identity federation** | every pod on every AKS cluster |
| 2 | **Federation from a trusted external issuer** (GitHub Actions OIDC) | Terraform plan/deploy pipelines |
| 3 | Certificate credential on an app registration | nothing today; only if a tool supports neither 1 nor 2 |
| 4 | Client secret | **only** for clusters outside Azure (section 5): Terraform-managed, maximum lifetime, zone-scoped |

Why no secrets: Entra guidance is "don't use password credentials". Both controllers we run
against DNS (external-dns, cert-manager) support workload identity and client secrets but
*not* certificates, so tier 3 is not an option for them. On AKS tier 1 is free and already
wired. A cluster outside Azure has neither a managed identity nor, unless it is Arc-connected,
an OIDC issuer Entra can trust, which leaves tier 4 for it.

## 2. Granularity: one identity per workload per cluster

* **One user-assigned managed identity per Kubernetes service account per cluster.**
  Name `id-<component>-<cluster>` (e.g. `id-external-dns-dev-westus3-01`); the local cluster's equivalent is `sp-dns-local` (section 5).
  Microsoft allows sharing an identity when permission sets are identical, but separate
  identities give per-component audit trails, independent revocation, and keep each identity far
  from the 20-federated-credential limit. Identities are free.
* **Never share an identity across environments** (CAF). dev and prod each have their own, even
  for the same component.
* **Service account ↔ identity is 1:1.** Federated credential: issuer = the cluster's OIDC
  issuer URL, subject `system:serviceaccount:<namespace>:<name>`, audience
  `api://AzureADTokenExchange`. The subject is not validated at creation; a typo fails only at
  token exchange, so the module derives it from one `namespace/name` variable.
* Pods opt in with label `azure.workload.identity/use: "true"`; the service account carries
  `azure.workload.identity/client-id`. The webhook injects `AZURE_FEDERATED_TOKEN_FILE`,
  `AZURE_TENANT_ID` and the projected token volume. Restart pods after changing the annotation.

## 3. Placement and scope

* **Identity lives with the cluster**: in the stamp's resource group, in the environment's
  subscription. The local cluster has no Azure footprint at all; its service principal is an
  Entra object and its role assignments sit on the zone, so that unit runs with the zones in
  the connectivity subscription (`live/platform/dns-principals`).
* **Role assignments go on the target resource, cross-subscription where needed.** The DNS
  zones live in `connectivity/rg-dns-public`; a dev identity gets `DNS Zone Contributor` on
  `dev.azure.example.com` only, never on the resource group or subscription. This is the
  existing `modules/aks-spoke/identity.tf` pattern and it already crosses subscriptions.
* **Built-in roles first** (CAF). A custom role only when no built-in role is narrow enough,
  defined once at the `mg-<prefix>` management group.
* **Role assignments are created by Terraform**, by the deploy identity (Owner at the
  management group, see `docs/github-oidc-setup.md`). Creating a role assignment needs
  RBAC Administrator or Owner; Contributor cannot. Propagation can take up to ten minutes,
  and Entra group membership changes can take hours because tokens are cached ~24h, so roles
  are assigned **directly to the identity, never via a group**.
* Clean up: user-assigned identities and their role assignments are not deleted with the
  workload. Terraform owns both so `destroy` removes them; orphans show as
  "Identity not found" in the portal.

## 4. Component matrix

What each platform component needs. `zone` = `<env>.azure.example.com`.

| component | identity | role | scope | notes |
|---|---|---|---|---|
| external-dns | `id-external-dns-<cluster>` | DNS Zone Contributor **+ Reader** | zone **+ `rg-dns-public`** | Reader on the RG is required by the Azure provider (zone listing); documented in the external-dns Azure tutorial |
| cert-manager (DNS-01) | `id-cert-manager-<cluster>` | DNS Zone Contributor | zone | `managedIdentity.clientID` in the ClusterIssuer; pod label via Helm `podLabels` |
| external-dns + cert-manager on a **local cluster** | `sp-dns-<env>` (one SP for both, section 5) | DNS Zone Contributor + Reader | zone + `rg-dns-public` | client secret; `clientID` + `clientSecretSecretRef` in the ClusterIssuer, `aadClientSecret` in azure.json |
| External Secrets Operator | `id-external-secrets-<cluster>` (AKS) / `sp-eso-<env>` (local, section 5) | Key Vault Secrets User | `kv-<prefix>-<env>` | preferred over the Key Vault CSI driver: secrets become normal Kubernetes Secrets Argo CD can reason about; one `ClusterSecretStore` per cluster. The vault is the cluster's only secret source; ESO's own credential is the one secret loaded by hand |
| ACR image pull (AKS) | **kubelet identity** (`<cluster>-agentpool`) | AcrPull | registry | not workload identity; `--attach-acr` / Terraform role assignment on the kubelet identity |
| ACR image pull (**local cluster**) | ACR repository-scoped token `acr-pull-<env>` (not an Entra identity) | content/read + metadata/read | the listed repositories | ADR-026; password in the environment vault (`acr-pull-*`), rotated by Terraform; the cluster's `imagePullSecret` via External Secrets |
| Application image push (GitHub Actions) | `id-gh-<repo>-<env>` (`modules/github-actions-identity`) | AcrPush | the environment's registry | tier 2 via a managed identity: federated credential per subject (`ref:refs/heads/<branch>`, ...) with the repo's immutable OIDC subject prefix; `azure/login` + `az acr login` in the workflow, no secret |
| Container Insights / Managed Prometheus | AKS add-on identity | managed by AKS | — | no action; legacy auth retired 2026-09-30 |
| Velero / backups | `id-velero-<cluster>` | Storage Blob Data Contributor | backup container | when added |
| Argo CD SSO (Entra) | app registration `argocd-<env>` | — | — | Argo CD 3.x supports `oidc.config.azure.useWorkloadIdentity: true`, so no client secret; the Argo CD server pod gets `id-argocd-<cluster>` |
| Terraform plan (PRs) | app `gh-cloud-platform-plan` | Reader + Storage Blob Data Contributor | `mg-<prefix>`, state account | federated: `pull_request` |
| Terraform deploy | app `gh-cloud-platform-deploy` | Owner | `mg-<prefix>` | federated: `environment:<env>` and `ref:refs/heads/main`; immutable-subject prefix, see `docs/github-oidc-setup.md` |

Pipelines use app registrations rather than managed identities because GitHub is an external
issuer and Microsoft documents both options without preference; app registrations are what
`bootstrap/setup-oidc.sh` already manages.

## 5. Local clusters: a Terraform-managed service principal

`local` (a laptop cluster, e.g. Rancher Desktop / k3s) runs outside Azure. The options were:

1. **Azure Arc-enabled Kubernetes** - Azure hosts an OIDC issuer for the cluster and installs
   the workload identity webhook, so the cluster can use tier 1 like AKS. Documented and k3s
   is validated, but it means Arc agents on the laptop (~850 MB), a kube-apiserver flag in the
   k3s config, quarterly signing-key rotation, and re-connecting after every factory reset.
2. **Service principal with a client secret** (tier 4), scoped to the one zone the cluster may
   write.

**Decision (2026-11-08): option 2.** The blast radius is a development zone, the laptop is
not a production system, and Arc's operational overhead is not worth it for that. The
exception is bounded as follows:

* **Terraform owns the principal.** `modules/public-dns-principals`, applied from
  `live/platform/dns-principals`, creates one Entra application + service principal
  `sp-dns-<env>` for every entry in `platform.hcl: external_environments`, with
  `DNS Zone Contributor` on `<env>.azure.example.com` and `Reader` on `rg-dns-public`
  (external-dns lists zones in the resource group). Nothing else, nowhere else. Adding a second
  local environment to `external_environments` gives it a zone and a principal in one apply.
* **Secret lifetime is the maximum, 24 months** (`dns_principal_secret_days = 730` in
  `platform.hcl`). That is the longest the Entra portal allows; the Graph API behind Terraform
  accepts longer unless a tenant app management policy caps it, so the number is a
  deliberate choice, not a limit. A `time_rotating` resource replaces the secret on the first
  apply after it elapses, and `secret_end_dates` is an output, so expiry is visible in every
  plan. The old secret stays valid until that apply, so re-running the manifests script right
  after is a zero-downtime rotation.
* **The secret lives in state and in the cluster, nowhere else.** It is a sensitive output
  (`client_secrets`, `azure_json`); `<gitops-repo>/scripts/azure-dns-local-credentials.sh`
  reads it with `terragrunt output -json` and writes the two cluster secrets
  (`external-dns/azure-config-file`, `cert-manager/azuredns-sp`). It is never written to a
  file in either repo. Only the client ID, an identifier, is committed (in the ClusterIssuer).
* **Ownership.** The applying principal and `gh-cloud-platform-deploy` own the application,
  so the deploy pipeline can manage it with `Application.ReadWrite.OwnedBy` alone
  (`docs/github-oidc-setup.md`).
* **Revocation** is `terragrunt destroy` of the unit, or deleting the password in Entra; the
  cluster then simply stops publishing records.

**Key Vault for a local cluster** (ADR-024) follows the same shape: `modules/local-cluster`
(applied from `live/<sub>/<env>/local-cluster`, dev subscription for `local`) creates
`rg-<prefix>-<env>`, an RBAC-mode vault `kv-<prefix>-<env>` and a second principal `sp-eso-<env>`
with Key Vault Secrets User on that vault only. Terraform writes the DNS principal's credentials
and generated secrets (oauth2-proxy cookie) into the vault and creates placeholders for the Google
OAuth client whose values an operator sets once (Terraform ignores them afterwards); External Secrets Operator syncs everything into the cluster. The ESO credential is the
one secret an operator loads onto a cluster (`<gitops-repo>/scripts/bootstrap-external-secrets.sh`).
One principal per component, as on AKS: `sp-dns-<env>` writes DNS, `sp-eso-<env>` reads the vault.

**Container registry for a local cluster** (ADR-026): `enable_acr` in `modules/local-cluster`
adds a Basic registry `cr<prefix><env>`. No third principal is added for the cluster: pulls use an
ACR repository-scoped token (native to the registry, read-only, scoped to the listed images)
whose password Terraform rotates and stores in the vault; pushes come from GitHub Actions of
the source repositories through `modules/github-actions-identity` (a managed identity with
AcrPush and one federated credential per branch - tier 2). Anything beyond DNS + Key Vault +
registry still means revisiting Arc rather than more secrets.

## 6. Where things live in this repo

```
modules/aks-spoke/identity.tf        UAMI + federated credential + zone roles per AKS stamp (external-dns today; cert-manager next)
modules/service-principal/           one Entra app + SP + Terraform-rotated secret (the tier-4 building block)
modules/github-actions-identity/     managed identity + federated credentials for a GitHub repo's workflows + roles (tier-2 building block)
modules/public-dns-principals/       sp-dns-<env> + zone roles per external environment (built on modules/service-principal)
modules/local-cluster/               rg + Key Vault + sp-eso-<env> + vault secrets (+ ACR, push identities, pull token) for an external environment
live/platform/dns-principals/        applies public-dns-principals for platform.hcl external_environments (connectivity)
live/dev/local/local-cluster/        applies local-cluster for local (dev subscription; opt-in)
bootstrap/setup-oidc.sh              pipeline app registrations + their Graph app roles (unchanged flow)
```

Terraform outputs the client IDs; they are committed into `<gitops-repo>`
overlays as plain values. Client, tenant and subscription IDs are identifiers, not credentials
(in *this* repo even those stay out of Git by policy - `.claude/rules/no-secrets.md`).

Each stamp outputs `external_dns_client_id`, `cert_manager_client_id` and
`external_secrets_client_id`; the environment's vault URI comes from `live/<env>/keyvault`.

## 7. Governance

* **Tenant policy**: the tenant's default app management policy has no password restriction
  today (checked 2026-11-08). If one is added to block new secrets on app registrations, it
  must exempt `sp-dns-*` (a targeted `appManagementPolicy`) or this unit stops applying.
* **Exceptions** to the no-secret rule are exactly the section 5 principals: Terraform-owned,
  `rotate_when_changed` against a `time_rotating`, expiry visible as an output, the value held
  only in state and in the cluster. A new exception needs the same shape and an ADR.
* **Ownership**: every app registration has at least two owners and is reviewed quarterly;
  app instance property lock on sensitive properties.
* **Monitoring**: service principal and managed identity sign-ins flow to the management
  subscription's Log Analytics workspace (CAF). Alert on sign-ins from unexpected issuers.
* **Conditional Access for workload identities** is available if the tenant later adds
  Workload Identities Premium; not required for this design.
* **Audit the limits**: ≤ 20 federated credentials per identity, create them sequentially
  (parallel creation on one identity returns 409), expect a few seconds to minutes of
  propagation and retry token requests.
