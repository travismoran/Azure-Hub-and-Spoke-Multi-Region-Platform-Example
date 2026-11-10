#!/usr/bin/env bash
#
# Tenant hygiene after the example's platform layer is gone (plan 001):
#   1. rename the original "Pay-As-You-Go" subscription to "management"
#   2. give the signed-in user Owner on connectivity/dev/prod directly
#      (today that access comes only from Owner at the tenant root)
#   3. at the tenant root "/", replace Owner + User Access Administrator with
#      Management Group Contributor + Resource Policy Contributor - enough
#      to apply live/platform, far less than Owner over everything.
# Step 3 removes your own root access: it only runs after step 2 succeeded
# and after you type "trim". Re-elevate any time with
#   az rest --method post --url "https://management.azure.com/providers/Microsoft.Authorization/elevateAccess?api-version=2016-07-01"
# (docs/subscriptions.md).
set -euo pipefail
: "${TG_SUBSCRIPTION_MANAGEMENT:?source .env first}"; : "${TG_SUBSCRIPTION_CONNECTIVITY:?}"; : "${TG_SUBSCRIPTION_DEV:?}"; : "${TG_SUBSCRIPTION_PROD:?}"
ME=$(az ad signed-in-user show --query id -o tsv)

echo ">> 1. rename management subscription"
az rest --method post --body '{"subscriptionName":"management"}' \
  --url "https://management.azure.com/subscriptions/${TG_SUBSCRIPTION_MANAGEMENT}/providers/Microsoft.Subscription/rename?api-version=2021-10-01" --output none \
  && echo "   renamed to 'management' (the portal catches up in a few minutes)"

echo ">> 2. direct Owner on the role subscriptions"
for s in "${TG_SUBSCRIPTION_CONNECTIVITY}" "${TG_SUBSCRIPTION_DEV}" "${TG_SUBSCRIPTION_PROD}"; do
  az role assignment create --assignee-object-id "${ME}" --assignee-principal-type User --role Owner \
    --scope "/subscriptions/${s}" --output none 2>/dev/null || echo "   (already Owner on ${s: -4})"
done
for role in "Management Group Contributor" "Resource Policy Contributor"; do
  az role assignment create --assignee-object-id "${ME}" --assignee-principal-type User --role "${role}" --scope "/" --output none 2>/dev/null \
    || echo "   (${role} at / already assigned)"
done

echo ">> verify: direct Owner on all four subscriptions"
for s in "${TG_SUBSCRIPTION_MANAGEMENT}" "${TG_SUBSCRIPTION_CONNECTIVITY}" "${TG_SUBSCRIPTION_DEV}" "${TG_SUBSCRIPTION_PROD}"; do
  az role assignment list --assignee "${ME}" --scope "/subscriptions/${s}" --role Owner --query '[0].roleDefinitionName' -o tsv | grep -q Owner \
    || { echo "   missing Owner on ${s} - not trimming root access." >&2; exit 1; }
done

echo ">> 3. trim tenant-root access (Owner + User Access Administrator at /)"
read -r -p "   type 'trim' to continue, anything else to stop here: " answer
[[ "${answer}" == "trim" ]] || { echo "   left root roles in place."; exit 0; }
az role assignment delete --assignee "${ME}" --role Owner --scope "/" --output none
az role assignment delete --assignee "${ME}" --role "User Access Administrator" --scope "/" --output none
echo "   done. Remaining at /: Management Group Contributor, Resource Policy Contributor."
