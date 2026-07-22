#!/usr/bin/env bash
#
# Bootstrap the Azure Storage account that holds Terraform remote state.
# Idempotent: safe to re-run.
#
# Required environment variables (source your .env first - see .env.example):
#   ARM_SUBSCRIPTION_ID       target subscription
#   TG_STATE_RESOURCE_GROUP   resource group to create for state
#   TG_STATE_STORAGE_ACCOUNT  globally-unique storage account name
# Optional:
#   TG_STATE_LOCATION         region for the state resources (default westus3)
#   AZURE_CLIENT_ID           app registration used by GitHub Actions OIDC;
#                             if set, it is granted access to state too.
#
# Costs: Standard_LRS storage with a few KB of state is effectively free
# (well under $1/month).

set -euo pipefail

: "${ARM_SUBSCRIPTION_ID:?Set ARM_SUBSCRIPTION_ID (source your .env)}"
: "${TG_STATE_RESOURCE_GROUP:?Set TG_STATE_RESOURCE_GROUP (source your .env)}"
: "${TG_STATE_STORAGE_ACCOUNT:?Set TG_STATE_STORAGE_ACCOUNT (source your .env)}"
TG_STATE_LOCATION="${TG_STATE_LOCATION:-westus3}"

echo ">> Using subscription ${ARM_SUBSCRIPTION_ID}"
az account set --subscription "${ARM_SUBSCRIPTION_ID}"

echo ">> Creating resource group ${TG_STATE_RESOURCE_GROUP} in ${TG_STATE_LOCATION}"
az group create \
  --name "${TG_STATE_RESOURCE_GROUP}" \
  --location "${TG_STATE_LOCATION}" \
  --output none

echo ">> Creating storage account ${TG_STATE_STORAGE_ACCOUNT}"
az storage account create \
  --name "${TG_STATE_STORAGE_ACCOUNT}" \
  --resource-group "${TG_STATE_RESOURCE_GROUP}" \
  --location "${TG_STATE_LOCATION}" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --allow-shared-key-access false \
  --output none

echo ">> Enabling blob versioning and soft delete"
az storage account blob-service-properties update \
  --account-name "${TG_STATE_STORAGE_ACCOUNT}" \
  --resource-group "${TG_STATE_RESOURCE_GROUP}" \
  --enable-versioning true \
  --enable-delete-retention true \
  --delete-retention-days 14 \
  --output none

STORAGE_ID=$(az storage account show \
  --name "${TG_STATE_STORAGE_ACCOUNT}" \
  --resource-group "${TG_STATE_RESOURCE_GROUP}" \
  --query id --output tsv)

echo ">> Granting Storage Blob Data Contributor to the signed-in user"
CURRENT_USER_ID=$(az ad signed-in-user show --query id --output tsv)
az role assignment create \
  --assignee-object-id "${CURRENT_USER_ID}" \
  --assignee-principal-type User \
  --role "Storage Blob Data Contributor" \
  --scope "${STORAGE_ID}" \
  --output none 2>/dev/null || echo "   (role assignment already exists)"

if [[ -n "${AZURE_CLIENT_ID:-}" ]]; then
  echo ">> Granting Storage Blob Data Contributor to CI app ${AZURE_CLIENT_ID}"
  CI_SP_ID=$(az ad sp show --id "${AZURE_CLIENT_ID}" --query id --output tsv)
  az role assignment create \
    --assignee-object-id "${CI_SP_ID}" \
    --assignee-principal-type ServicePrincipal \
    --role "Storage Blob Data Contributor" \
    --scope "${STORAGE_ID}" \
    --output none 2>/dev/null || echo "   (role assignment already exists)"
fi

echo ">> Creating blob container 'tfstate' (RBAC auth; role grants can take ~1 min to propagate)"
for attempt in 1 2 3 4 5; do
  if az storage container create \
    --name tfstate \
    --account-name "${TG_STATE_STORAGE_ACCOUNT}" \
    --auth-mode login \
    --output none 2>/dev/null; then
    break
  fi
  echo "   attempt ${attempt} failed (RBAC propagation?), retrying in 20s..."
  sleep 20
done

cat <<SUMMARY

Done. Terraform state backend is ready:

  resource group:  ${TG_STATE_RESOURCE_GROUP}
  storage account: ${TG_STATE_STORAGE_ACCOUNT}
  container:       tfstate

Keep these exported in your shell (they are read by live/root.hcl):
  export TG_STATE_RESOURCE_GROUP="${TG_STATE_RESOURCE_GROUP}"
  export TG_STATE_STORAGE_ACCOUNT="${TG_STATE_STORAGE_ACCOUNT}"

For GitHub Actions, set the same two values as repository variables,
plus AZURE_CLIENT_ID / AZURE_TENANT_ID / AZURE_SUBSCRIPTION_ID
(see docs/github-oidc-setup.md).
SUMMARY
