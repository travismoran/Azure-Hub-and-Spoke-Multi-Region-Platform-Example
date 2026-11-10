#!/usr/bin/env bash
#
# Stop or start every AKS cluster of an environment (node pools deallocate;
# control plane, state and addresses are kept). Saves the node cost
# overnight; the cluster comes back in ~3 minutes.
#   source .env && scripts/aks-power.sh stop  dev
#   source .env && scripts/aks-power.sh start dev
# The scheduled version is .github/workflows/aks-schedule.yml.
set -euo pipefail
action="${1:?usage: $0 stop|start <env>}"; env="${2:?usage: $0 stop|start <env>}"
[[ "${action}" == "stop" || "${action}" == "start" ]] || { echo "action must be stop or start" >&2; exit 2; }
sub_var="TG_SUBSCRIPTION_$(echo "${env}" | tr 'a-z' 'A-Z')"; sub="${!sub_var:-${ARM_SUBSCRIPTION_ID:?}}"

mapfile -t clusters < <(az aks list --subscription "${sub}" \
  --query "[?tags.Environment=='${env}' && tags.ManagedBy=='Terragrunt'].{n:name,g:resourceGroup,p:powerState.code}" -o tsv)
[[ ${#clusters[@]} -gt 0 ]] || { echo "no ${env} clusters found"; exit 0; }
for line in "${clusters[@]}"; do
  IFS=$'\t' read -r name rg state <<<"${line}"
  if [[ "${action}" == "stop" && "${state}" == "Stopped" ]] || [[ "${action}" == "start" && "${state}" == "Running" ]]; then
    echo ">> ${name}: already ${state}"; continue
  fi
  echo ">> ${action} ${name} (${rg})"
  az aks "${action}" --subscription "${sub}" --name "${name}" --resource-group "${rg}" --no-wait
done
