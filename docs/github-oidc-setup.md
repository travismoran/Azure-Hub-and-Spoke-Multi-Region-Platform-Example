# GitHub Actions OIDC setup

The `plan` workflow authenticates to Azure with **OpenID Connect federated
credentials** - GitHub exchanges a short-lived token with Entra ID, so no
client secret ever exists, let alone gets stored in the repo.

Two identities keep blast radius small: a read-only one for PR plans (Reader
on Azure; it can only write the state blobs, which terraform locks even to
plan) and a deploying one for `deploy.yml` (main branch, manual dispatch). Both are
app registrations with federated credentials; neither has a secret.

`bootstrap/setup-oidc.sh` does everything below idempotently
(`source .env && ./bootstrap/setup-oidc.sh`; needs `az login` with Owner on
the subscriptions plus User Access Administrator at the tenant root, and
`gh auth login` with repo admin). The commands, for reference:

```bash
GITHUB_REPO="<owner>/<repo>"
source ../.env   # ARM_TENANT_ID, TG_SUBSCRIPTION_*, TG_STATE_*, TG_NAME_PREFIX

# 1. App registration + service principal
APP_ID=$(az ad app create --display-name "gh-azure-aks-platform" --query appId -o tsv)
az ad sp create --id "$APP_ID" --query id -o tsv

# 2. Federated credentials: PRs → plan identity; main branch → deploy identity.
#    The subject prefix is not always repo:<owner>/<repo>: repos created in or
#    moved into an org since 2025 use GitHub's immutable subjects
#    (repo:<owner>@<id>/<repo>@<id>), so read it.
SUB_PREFIX=$(gh api "repos/${GITHUB_REPO}/actions/oidc/customization/sub" --jq .sub_claim_prefix)
fc() { az ad app federated-credential create --id "$1" --parameters "{
  \"name\": \"$2\",
  \"issuer\": \"https://token.actions.githubusercontent.com\",
  \"subject\": \"${SUB_PREFIX}:$3\",
  \"audiences\": [\"api://AzureADTokenExchange\"]
}"; }
fc "$PLAN_APP"   github-pr   pull_request
fc "$PLAN_APP"   github-main ref:refs/heads/main   # workflow_dispatch of plan.yml
fc "$DEPLOY_APP" github-main ref:refs/heads/main          # aks-schedule.yml
for e in platform dev prod; do fc "$DEPLOY_APP" "github-env-$e" "environment:$e"; done  # deploy.yml

# 3. RBAC: Reader is enough for plan-only CI. Repeat per subscription in
#    the multi-subscription layout (connectivity, dev; docs/subscriptions.md),
#    or assign once at mg-<prefix>.
#    (Use Contributor + User Access Administrator instead if you later add
#    gated applies.)
az role assignment create \
  --assignee "$APP_ID" \
  --role Reader \
  --scope "/subscriptions/$SUBSCRIPTION_ID"

# 4. State access
STORAGE_ID=$(az storage account show --name "$TG_STATE_STORAGE_ACCOUNT" \
  --resource-group "$TG_STATE_RESOURCE_GROUP" --query id -o tsv)
az role assignment create --assignee "$PLAN_APP"   --role "Storage Blob Data Contributor" --scope "$STORAGE_ID"  # init leases the state blob even for plan
az role assignment create --assignee "$DEPLOY_APP" --role "Storage Blob Data Contributor" --scope "$STORAGE_ID"

# 5. Microsoft Graph app roles (tenant-level, granted by a Global Administrator):
#    live/platform/dns-principals manages Entra applications (docs/identity.md §5),
#    which Azure RBAC does not cover. Read for both; create/manage-owned for deploy.
GRAPH=$(az ad sp show --id 00000003-0000-0000-c000-000000000000 --query id -o tsv)
role() { az ad sp show --id 00000003-0000-0000-c000-000000000000 --query "appRoles[?value=='$1'].id" -o tsv; }
grant() { az rest --method POST --url "https://graph.microsoft.com/v1.0/servicePrincipals/$1/appRoleAssignments" \
  --body "{\"principalId\":\"$1\",\"resourceId\":\"$GRAPH\",\"appRoleId\":\"$(role "$2")\"}"; }
grant "$(az ad sp show --id "$PLAN_APP"   --query id -o tsv)" Application.Read.All
grant "$(az ad sp show --id "$DEPLOY_APP" --query id -o tsv)" Application.Read.All
grant "$(az ad sp show --id "$DEPLOY_APP" --query id -o tsv)" Application.ReadWrite.OwnedBy
```

`Application.ReadWrite.OwnedBy` only reaches applications the deploy identity owns, which is
why `modules/public-dns-principals` lists it as an owner of everything it creates. Without
step 5, `plan.yml` fails on `live/platform/dns-principals` with an `Authorization_RequestDenied`
from Graph.

Then set these **repository variables** (Settings → Secrets and variables →
Actions → Variables). They are deliberately variables, not secrets: client
IDs, tenant IDs, and subscription IDs are identifiers, not credentials -
there is nothing here a secret store needs to protect. That is the whole
point of OIDC.

| Variable | Value |
|---|---|
| `AZURE_CLIENT_ID` | `$DEPLOY_APP` (deploy.yml, aks-schedule.yml) |
| `AZURE_PLAN_CLIENT_ID` | `$PLAN_APP` (plan.yml; optional, falls back to `AZURE_CLIENT_ID`) |
| `AZURE_TENANT_ID` | `az account show --query tenantId -o tsv` |
| `AZURE_SUBSCRIPTION_ID` | your subscription id |
| `TG_STATE_RESOURCE_GROUP` | state resource group name |
| `TG_STATE_STORAGE_ACCOUNT` | state storage account name |
| `TG_SUBSCRIPTION_MANAGEMENT`, `TG_SUBSCRIPTION_CONNECTIVITY`, `TG_SUBSCRIPTION_DEV` | optional: the role subscriptions (docs/subscriptions.md); unset = everything in `AZURE_SUBSCRIPTION_ID` |

If a login fails with `AADSTS700213: No matching federated identity record
found for presented assertion subject 'repo:<owner>@<id>/<repo>@<id>:…'`,
the credentials were created with the plain prefix; re-run
`bootstrap/setup-oidc.sh`, which reads the real prefix.

Both workflows are gated on `vars.AZURE_CLIENT_ID != ''`; until the variable
is set they skip themselves and only the credential-free `ci` workflow runs.

`plan.yml` authenticates as `AZURE_PLAN_CLIENT_ID` when that variable is set
and falls back to `AZURE_CLIENT_ID`, so a single-app setup works too.
`aks-schedule.yml` (optional, `AKS_SCHEDULE_ENABLED=true`) uses the deploy
identity to stop/start dev clusters.

## Environments and approval gates

`deploy.yml` runs each target in the GitHub Environment of the same name,
created by `setup-oidc.sh` with a deployment branch policy of `main` only,
and the deploy identity has one federated credential per environment
subject. Environments are available on public repos and, for private repos,
on GitHub Team and above. The typed `confirm` input is the apply guard;
required reviewers or wait timers can be added on top where your plan
allows them (public repos, or GitHub Enterprise for private ones).
Per-environment variables can be added in the environment settings if a
target ever needs different values from the repository-level ones.
