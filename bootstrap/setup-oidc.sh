#!/usr/bin/env bash
#
# One-time: GitHub Actions OIDC identities for this repo + repository
# variables. Idempotent. Needs: az login as someone with Owner on the four
# subscriptions and User Access Administrator (or Owner) at the tenant root
# for the two root-scope roles; gh auth with repo admin.
#
#   source .env && GITHUB_REPO=<owner>/<repo> ./bootstrap/setup-oidc.sh
#
# Creates two app registrations with federated credentials (no secrets):
#   gh-cloud-platform-plan    PRs + main: Reader on every subscription,
#                             Management Group Reader at /, Blob Data Contributor on
#                             state (init leases the state blob even for a plan)
#   gh-cloud-platform-deploy  main + environments platform/dev/prod (deploy.yml,
#                             aks-schedule.yml): Owner on every subscription,
#                             Management Group Contributor + Resource Policy
#                             Contributor at /, Blob Data Contributor on state
#   + Graph app roles for both (Application.Read.All; deploy also
#     Application.ReadWrite.OwnedBy) so live/platform/dns-principals can plan/apply
# and sets the repository variables plan.yml / deploy.yml read.
set -euo pipefail

REPO="${GITHUB_REPO:?set GITHUB_REPO=<owner>/<repo> (the repository whose workflows deploy this platform)}"
# GitHub's OIDC subject prefix. With "immutable subjects" (the default for
# repos created or transferred into an org since 2025) it carries the owner
# and repository IDs - repo:<owner>@<id>/<repo>@<id> - so a renamed or
# re-created repo can never reuse the credential. Read it rather than assume.
SUB_PREFIX="$(gh api "repos/${REPO}/actions/oidc/customization/sub" --jq '.sub_claim_prefix // empty' 2>/dev/null || true)"
SUB_PREFIX="${SUB_PREFIX:-repo:${REPO}}"
echo ">> OIDC subject prefix: ${SUB_PREFIX}"
: "${ARM_TENANT_ID:?source .env first}"
: "${TG_SUBSCRIPTION_MANAGEMENT:?}"; : "${TG_SUBSCRIPTION_CONNECTIVITY:?}"; : "${TG_SUBSCRIPTION_DEV:?}"
: "${TG_STATE_RESOURCE_GROUP:?}"; : "${TG_STATE_STORAGE_ACCOUNT:?}"
SUBS=("${TG_SUBSCRIPTION_MANAGEMENT}" "${TG_SUBSCRIPTION_CONNECTIVITY}" "${TG_SUBSCRIPTION_DEV}" ${TG_SUBSCRIPTION_PROD:+"${TG_SUBSCRIPTION_PROD}"})

app() { # display-name -> appId (create if missing)
  local id; id=$(az ad app list --display-name "$1" --query '[0].appId' -o tsv)
  if [[ -z "${id}" ]]; then
    id=$(az ad app create --display-name "$1" --query appId -o tsv)
    az ad sp create --id "${id}" --output none
    echo "   created ${1}" >&2
  fi
  echo "${id}"
}
fedcred() { # appId name subject
  az ad app federated-credential create --id "$1" --parameters "{
    \"name\": \"$2\", \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"${SUB_PREFIX}:$3\", \"audiences\": [\"api://AzureADTokenExchange\"]}" --output none 2>/dev/null \
    || echo "   federated credential $2 exists"
}
grant() { # spObjectId role scope
  az role assignment create --assignee-object-id "$1" --assignee-principal-type ServicePrincipal \
    --role "$2" --scope "$3" --output none 2>/dev/null || echo "   ($2 at ${3##*/} already assigned)"
}

echo ">> app registrations"
PLAN_APP=$(app gh-cloud-platform-plan); DEPLOY_APP=$(app gh-cloud-platform-deploy)
sleep 10 # SP propagation
PLAN_SP=$(az ad sp show --id "${PLAN_APP}" --query id -o tsv); DEPLOY_SP=$(az ad sp show --id "${DEPLOY_APP}" --query id -o tsv)

echo ">> federated credentials"
fedcred "${PLAN_APP}" github-pr pull_request
fedcred "${PLAN_APP}" github-main ref:refs/heads/main
fedcred "${DEPLOY_APP}" github-main ref:refs/heads/main          # aks-schedule.yml (no environment)
for e in platform dev prod; do                                       # deploy.yml runs in environment <target>
  fedcred "${DEPLOY_APP}" "github-env-${e}" "environment:${e}"
done

echo ">> GitHub Environments platform/dev/prod (deployments from main only)"
for e in platform dev prod; do
  gh api -X PUT "repos/${REPO}/environments/${e}" \
    -F 'deployment_branch_policy[protected_branches]=false' -F 'deployment_branch_policy[custom_branch_policies]=true' --silent
  gh api -X POST "repos/${REPO}/environments/${e}/deployment-branch-policies" -f name=main -f type=branch --silent 2>/dev/null \
    || echo "   (branch policy main exists on ${e})"
done

echo ">> subscription RBAC"
for s in "${SUBS[@]}"; do
  grant "${PLAN_SP}" Reader "/subscriptions/${s}"
  grant "${DEPLOY_SP}" Owner "/subscriptions/${s}"
done

echo ">> tenant-root RBAC (management groups, policy)"
grant "${PLAN_SP}" "Management Group Reader" "/"
grant "${DEPLOY_SP}" "Management Group Contributor" "/"
grant "${DEPLOY_SP}" "Resource Policy Contributor" "/"

echo ">> state storage RBAC"
STORAGE_ID=$(az storage account show --name "${TG_STATE_STORAGE_ACCOUNT}" --resource-group "${TG_STATE_RESOURCE_GROUP}" \
  --subscription "${TG_SUBSCRIPTION_MANAGEMENT}" --query id -o tsv)
# Contributor, not Reader, for the plan identity too: terraform init takes a
# blob lease on the state file even for a plan, and a lease is a write.
grant "${PLAN_SP}" "Storage Blob Data Contributor" "${STORAGE_ID}"
grant "${DEPLOY_SP}" "Storage Blob Data Contributor" "${STORAGE_ID}"

echo ">> Microsoft Graph app roles (live/platform/dns-principals manages Entra apps; docs/identity.md §5)"
# Needs a Global Administrator (or Privileged Role Administrator) - the only
# step here that Azure RBAC cannot grant. Idempotent: skips existing grants.
GRAPH_SP=$(az ad sp show --id 00000003-0000-0000-c000-000000000000 --query id -o tsv)
graph_role() { az ad sp show --id 00000003-0000-0000-c000-000000000000 --query "appRoles[?value=='$1'].id" -o tsv; }
graph_grant() { # spObjectId roleValue
  local role_id; role_id=$(graph_role "$2")
  if az rest --method GET --url "https://graph.microsoft.com/v1.0/servicePrincipals/$1/appRoleAssignments" \
       --query "value[?appRoleId=='${role_id}'].id" -o tsv | grep -q .; then
    echo "   ($2 already granted)"; return
  fi
  az rest --method POST --url "https://graph.microsoft.com/v1.0/servicePrincipals/$1/appRoleAssignments" \
    --headers 'Content-Type=application/json' \
    --body "{\"principalId\":\"$1\",\"resourceId\":\"${GRAPH_SP}\",\"appRoleId\":\"${role_id}\"}" --output none
  echo "   granted $2"
}
graph_grant "${PLAN_SP}" Application.Read.All            # plan refreshes the app/SP resources
graph_grant "${DEPLOY_SP}" Application.Read.All
graph_grant "${DEPLOY_SP}" Application.ReadWrite.OwnedBy # create + manage the apps it owns

echo ">> GitHub repository variables (${REPO})"
gh variable set AZURE_CLIENT_ID -R "${REPO}" -b "${DEPLOY_APP}"
gh variable set AZURE_PLAN_CLIENT_ID -R "${REPO}" -b "${PLAN_APP}"
gh variable set AZURE_TENANT_ID -R "${REPO}" -b "${ARM_TENANT_ID}"
gh variable set AZURE_SUBSCRIPTION_ID -R "${REPO}" -b "${TG_SUBSCRIPTION_MANAGEMENT}"
gh variable set TG_SUBSCRIPTION_MANAGEMENT -R "${REPO}" -b "${TG_SUBSCRIPTION_MANAGEMENT}"
gh variable set TG_SUBSCRIPTION_CONNECTIVITY -R "${REPO}" -b "${TG_SUBSCRIPTION_CONNECTIVITY}"
gh variable set TG_SUBSCRIPTION_DEV -R "${REPO}" -b "${TG_SUBSCRIPTION_DEV}"
[[ -n "${TG_SUBSCRIPTION_PROD:-}" ]] && gh variable set TG_SUBSCRIPTION_PROD -R "${REPO}" -b "${TG_SUBSCRIPTION_PROD}"
gh variable set TG_STATE_RESOURCE_GROUP -R "${REPO}" -b "${TG_STATE_RESOURCE_GROUP}"
gh variable set TG_STATE_STORAGE_ACCOUNT -R "${REPO}" -b "${TG_STATE_STORAGE_ACCOUNT}"
gh variable set TG_STATE_CONTAINER -R "${REPO}" -b "${TG_STATE_CONTAINER:-tfstate}"
gh variable set TG_NAME_PREFIX -R "${REPO}" -b "${TG_NAME_PREFIX:-demo}"
echo "Done. plan.yml runs on the next PR; deploy.yml via Actions -> deploy -> Run workflow."
