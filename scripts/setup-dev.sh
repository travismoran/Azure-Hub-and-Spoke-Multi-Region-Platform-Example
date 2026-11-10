#!/usr/bin/env bash
#
# One-time developer setup. Idempotent.
#   1. Installs the pinned, checksum-verified tools (gitleaks, tflint, trivy,
#      terraform-docs) to ~/.local/bin via scripts/install-tools.sh
#   2. Activates the repo's git hooks (githooks/pre-commit, pre-push)
#   3. Runs a baseline secret scan so you start from a known-clean state
#
# Usage: ./scripts/setup-dev.sh
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"

# --- 1. pinned tools (gitleaks, tflint, trivy, terraform-docs) -------------
"${REPO_ROOT}/scripts/install-tools.sh"

# --- 2. git hooks -----------------------------------------------------------
current_hookspath="$(git -C "${REPO_ROOT}" config core.hooksPath || true)"
if [[ "${current_hookspath}" == "githooks" ]]; then
  echo ">> git hooks already active (core.hooksPath=githooks)"
else
  git -C "${REPO_ROOT}" config core.hooksPath githooks
  echo ">> Activated secret-scan hooks (core.hooksPath=githooks)"
fi

# --- 3. baseline scan -------------------------------------------------------
echo ">> Baseline scan: working tree"
gitleaks dir "${REPO_ROOT}" --redact --no-banner -c "${REPO_ROOT}/.gitleaks.toml"
echo ">> Baseline scan: full git history"
(cd "${REPO_ROOT}" && gitleaks git --redact --no-banner -c .gitleaks.toml)

echo
echo "Setup complete. Every commit and push is now gated by secret scanning."
