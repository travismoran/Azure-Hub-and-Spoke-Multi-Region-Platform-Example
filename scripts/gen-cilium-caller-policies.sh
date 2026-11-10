#!/usr/bin/env bash
#
# Collect every stamp's node subnets for an environment (from terragrunt
# outputs, or a prepared file with --subnets) and render the Cilium caller
# policies described in catalog/README.md.
#   scripts/gen-cilium-caller-policies.sh dev
#   scripts/gen-cilium-caller-policies.sh dev --subnets catalog/testdata/dev-subnets.json
set -euo pipefail
REPO_ROOT="$(git rev-parse --show-toplevel)"; cd "${REPO_ROOT}"
env="${1:?usage: $0 <env> [--subnets file.json]}"; shift
subnets=""
[[ "${1:-}" == "--subnets" ]] && subnets="${2:?}"

tmp="$(mktemp)"; trap 'rm -f "${tmp}"' EXIT
if [[ -z "${subnets}" ]]; then
  echo "{" > "${tmp}"; first=1
  for unit in live/"${env}"/*/aks-spoke*/; do
    [[ -d "${unit}" ]] || continue
    out=$(cd "${unit}" && terragrunt output -json 2>/dev/null) || { echo "skip ${unit} (no state)" >&2; continue; }
    id=$(echo "${out}" | python3 -I -c 'import json,sys; d=json.load(sys.stdin); print(d["stamp_id"]["value"])')
    nets=$(echo "${out}" | python3 -I -c 'import json,sys; d=json.load(sys.stdin); print(json.dumps(d["node_subnet_prefixes"]["value"]))')
    [[ ${first} -eq 1 ]] || echo "," >> "${tmp}"; first=0
    printf '  "%s": %s' "${id}" "${nets}" >> "${tmp}"
  done
  echo "}" >> "${tmp}"; subnets="${tmp}"
fi
python3 -I scripts/gen-cilium-caller-policies.py "${env}" "${subnets}" "catalog/out/${env}"
