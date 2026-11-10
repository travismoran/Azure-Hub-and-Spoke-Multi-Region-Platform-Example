#!/usr/bin/env bash
#
# Install the pinned, checksum-verified CLI tools this repo's checks need
# (gitleaks, tflint, trivy, terraform-docs) into ~/.local/bin. Idempotent;
# used by scripts/setup-dev.sh locally and by .github/workflows/ci.yml.
# terraform/terragrunt themselves come from .tool-versions (asdf/mise) or
# the CI setup actions.
#
# Usage: scripts/install-tools.sh [tool ...]     (default: all)
set -euo pipefail

GITLEAKS_VERSION="8.24.3"
TFLINT_VERSION="0.65.0"
TRIVY_VERSION="0.76.2"
TERRAFORM_DOCS_VERSION="0.24.0"

INSTALL_DIR="${INSTALL_DIR:-${HOME}/.local/bin}"
mkdir -p "${INSTALL_DIR}"

case "$(uname -s)_$(uname -m)" in
  Linux_x86_64) os=linux; arch=amd64; trivy_os=Linux; trivy_arch=64bit ;;
  Linux_aarch64) os=linux; arch=arm64; trivy_os=Linux; trivy_arch=ARM64 ;;
  Darwin_arm64) os=darwin; arch=arm64; trivy_os=macOS; trivy_arch=ARM64 ;;
  *) echo "Unsupported platform $(uname -s)/$(uname -m)" >&2; exit 1 ;;
esac

# sha256 from each project's official release checksum file.
declare -A SHA=(
  ["gitleaks_linux_amd64"]="9991e0b2903da4c8f6122b5c3186448b927a5da4deef1fe45271c3793f4ee29c"
  ["gitleaks_linux_arm64"]="5f2edbe1f49f7b920f9e06e90759947d3c5dfc16f752fb93aaafc17e9d14cf07"
  ["gitleaks_darwin_arm64"]="b90f13bb8c90ab72083d9b0c842e39dafb82c0e5c3f872f407366b7a58909013"
  ["tflint_linux_amd64"]="d4c545ed2e29d6338604b586f34f544f380f70f243aa72f7b484713835eaec61"
  ["tflint_linux_arm64"]="843017c47a98be1de4d88fa038daa293770fe25cd01656c4f08b2e30d1d3b3a0"
  ["tflint_darwin_arm64"]="5a71c63481ba56760864298011fdb7317a9ae80a0bbaeceefa35883c7f62ac71"
  ["trivy_linux_amd64"]="bc0fc726e017b8927a62b2d3531d7a84ee01769daf5c99ed866dced54089fdbf"
  ["trivy_linux_arm64"]="ab9d51f86e6a5fb936f605faff6b593ac51bc378fff4d3e8b9d58358b9c367c3"
  ["trivy_darwin_arm64"]="ae7ea358326960406b703c77b2ac490190797d80b306b5b50c2a27221da0a5b8"
  ["terraform-docs_linux_amd64"]="9005daf969de0b50134493a2c00078b49f5f5b39d021cda7c89bf4d4f3d776d3"
  ["terraform-docs_linux_arm64"]="d12bd7b73c1fc9c64efc79f8157dd713dabd559f1ecf3cfc0f42e32279a155fd"
  ["terraform-docs_darwin_arm64"]="f6b114f4b032f3f9202ab6c23bfd28c3c8e68aeeb8a8f12fc118bf2073081d71"
)

tmp="$(mktemp -d)"; trap 'rm -rf "${tmp}"' EXIT

installed_version() { # tool -> version string or ""
  command -v "$1" >/dev/null 2>&1 || { echo ""; return; }
  case "$1" in
    gitleaks) gitleaks version 2>/dev/null ;;
    tflint) tflint --version 2>/dev/null | head -1 | sed -E 's/.*version ([0-9.]+).*/\1/' ;;
    trivy) trivy --version 2>/dev/null | head -1 | sed -E 's/.*Version: ([0-9.]+).*/\1/' ;;
    terraform-docs) terraform-docs --version 2>/dev/null | sed -E 's/.*version v([0-9.]+).*/\1/' ;;
  esac
}

fetch() { # url dest key
  curl -sSfL -o "$2" "$1"
  echo "${SHA[$3]}  $2" | sha256sum -c - >/dev/null || { echo "CHECKSUM MISMATCH for $3 - aborting." >&2; exit 1; }
}

install_gitleaks() {
  local f="gitleaks_${GITLEAKS_VERSION}_${os}_$( [ "$arch" = amd64 ] && echo x64 || echo arm64 ).tar.gz"
  fetch "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/${f}" "${tmp}/${f}" "gitleaks_${os}_${arch}"
  tar -xzf "${tmp}/${f}" -C "${tmp}" gitleaks && install -m 0755 "${tmp}/gitleaks" "${INSTALL_DIR}/gitleaks"
}
install_tflint() {
  local f="tflint_${os}_${arch}.zip"
  fetch "https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}/${f}" "${tmp}/${f}" "tflint_${os}_${arch}"
  python3 -I -c "import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extract('tflint', sys.argv[2])" "${tmp}/${f}" "${tmp}"
  install -m 0755 "${tmp}/tflint" "${INSTALL_DIR}/tflint"
}
install_trivy() {
  local f="trivy_${TRIVY_VERSION}_${trivy_os}-${trivy_arch}.tar.gz"
  fetch "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/${f}" "${tmp}/${f}" "trivy_${os}_${arch}"
  tar -xzf "${tmp}/${f}" -C "${tmp}" trivy && install -m 0755 "${tmp}/trivy" "${INSTALL_DIR}/trivy"
}
install_terraform-docs() {
  local f="terraform-docs-v${TERRAFORM_DOCS_VERSION}-${os}-${arch}.tar.gz"
  fetch "https://github.com/terraform-docs/terraform-docs/releases/download/v${TERRAFORM_DOCS_VERSION}/${f}" "${tmp}/${f}" "terraform-docs_${os}_${arch}"
  tar -xzf "${tmp}/${f}" -C "${tmp}" terraform-docs && install -m 0755 "${tmp}/terraform-docs" "${INSTALL_DIR}/terraform-docs"
}

tools=("$@"); [ ${#tools[@]} -eq 0 ] && tools=(gitleaks tflint trivy terraform-docs)
for tool in "${tools[@]}"; do
  want_var="$(echo "${tool}" | tr 'a-z-' 'A-Z_')_VERSION"; want="${!want_var}"
  if [[ "$(installed_version "${tool}")" == "${want}" ]]; then
    echo ">> ${tool} ${want} already installed"
  else
    echo ">> installing ${tool} ${want}"; "install_${tool}"
  fi
done
case ":${PATH}:" in *":${INSTALL_DIR}:"*) ;; *) echo "NOTE: add ${INSTALL_DIR} to your PATH." ;; esac
