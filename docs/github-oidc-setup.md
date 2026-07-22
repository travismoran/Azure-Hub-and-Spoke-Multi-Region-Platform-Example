# GitHub Actions OIDC setup

The `plan` workflow authenticates to Azure with **OpenID Connect federated
credentials** - GitHub exchanges a short-lived token with Entra ID, so no
client secret ever exists, let alone gets stored in the repo.

One-time setup, using your own values throughout:

```bash
SUBSCRIPTION_ID="<your subscription id>"
GITHUB_REPO="<owner>/<repo>"        # e.g. yourname/azure-aks-platform

# 1. App registration + service principal
APP_ID=$(az ad app create --display-name "gh-azure-aks-platform" --query appId -o tsv)
az ad sp create --id "$APP_ID" --query id -o tsv

# 2. Federated credentials: PRs and pushes to main
az ad app federated-credential create --id "$APP_ID" --parameters '{
  "name": "github-pr",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:'"$GITHUB_REPO"':pull_request",
  "audiences": ["api://AzureADTokenExchange"]
}'
az ad app federated-credential create --id "$APP_ID" --parameters '{
  "name": "github-main",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:'"$GITHUB_REPO"':ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"]
}'

# 3. RBAC: Reader is enough for plan-only CI.
#    (Use Contributor + User Access Administrator instead if you later add
#    gated applies.)
az role assignment create \
  --assignee "$APP_ID" \
  --role Reader \
  --scope "/subscriptions/$SUBSCRIPTION_ID"

# 4. State access for backend reads during plan
source ../.env   # for TG_STATE_* values
STORAGE_ID=$(az storage account show \
  --name "$TG_STATE_STORAGE_ACCOUNT" \
  --resource-group "$TG_STATE_RESOURCE_GROUP" \
  --query id -o tsv)
az role assignment create \
  --assignee "$APP_ID" \
  --role "Storage Blob Data Contributor" \
  --scope "$STORAGE_ID"
```

Then set these **repository variables** (Settings → Secrets and variables →
Actions → Variables). They are deliberately variables, not secrets: client
IDs, tenant IDs, and subscription IDs are identifiers, not credentials -
there is nothing here a secret store needs to protect. That is the whole
point of OIDC.

| Variable | Value |
|---|---|
| `AZURE_CLIENT_ID` | `$APP_ID` from above |
| `AZURE_TENANT_ID` | `az account show --query tenantId -o tsv` |
| `AZURE_SUBSCRIPTION_ID` | your subscription id |
| `TG_STATE_RESOURCE_GROUP` | state resource group name |
| `TG_STATE_STORAGE_ACCOUNT` | state storage account name |

The `plan` workflow is gated on `vars.AZURE_CLIENT_ID != ''`, so forks that
skip all of this simply skip the job; the credential-free `ci` workflow still
runs everywhere.
