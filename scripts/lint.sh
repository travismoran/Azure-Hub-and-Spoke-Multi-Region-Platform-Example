#!/usr/bin/env bash
#
# Lint + security + docs checks (CLAUDE.md §4). Runs what ci.yml runs.
#   scripts/lint.sh          all checks
#   scripts/lint.sh tflint   | trivy | docs | docs-check
set -euo pipefail
REPO_ROOT="$(git rev-parse --show-toplevel)"; cd "${REPO_ROOT}"
export PATH="${HOME}/.local/bin:${PATH}"

run_tflint() {
  tflint --init --config "${REPO_ROOT}/.tflint.hcl" >/dev/null
  for m in modules/*/; do
    echo "== tflint ${m}"
    tflint --config "${REPO_ROOT}/.tflint.hcl" --chdir "${m}"
  done
}

run_trivy() {
  echo "== trivy config (modules + live)"
  trivy config --exit-code 1 --severity HIGH,CRITICAL --ignorefile .trivyignore --quiet \
    --skip-dirs '**/.terraform' --skip-dirs '**/.terragrunt-cache' --skip-dirs 'catalog' .
}

run_docs() { # regenerate modules/*/README.md
  for m in modules/*/; do terraform-docs -c .terraform-docs.yml "${m}" >/dev/null; echo "== terraform-docs ${m}README.md"; done
}

run_docs_check() { # regenerate, then fail if that changed anything tracked
  run_docs >/dev/null
  if ! git diff --quiet -- modules/*/README.md; then
    echo "STALE module README(s) - commit the regenerated files:" >&2
    git diff --stat -- modules/*/README.md >&2
    exit 1
  fi
  echo "== module READMEs up to date"
}

case "${1:-all}" in
  tflint) run_tflint ;;
  trivy) run_trivy ;;
  docs) run_docs ;;
  docs-check) run_docs_check ;;
  all) run_tflint; run_trivy; run_docs_check ;;
  *) echo "usage: $0 [tflint|trivy|docs|docs-check|all]" >&2; exit 2 ;;
esac
