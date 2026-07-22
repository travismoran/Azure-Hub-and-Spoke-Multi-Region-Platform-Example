# Rule: no secrets in this repository

This is a **public** repository. Treat every commit as world-readable forever
(mirrors and caches keep history even after force-pushes).

## Never commit

- Credentials of any kind: passwords, client secrets, storage account keys,
  SAS tokens, connection strings, certificates/private keys (`*.pem`,
  `*.pfx`, `*.key`), kubeconfigs, `kube_config`/`kube_admin_config` output.
- Terraform state (`*.tfstate*`) or `.terraform/` - state contains secrets
  (kubeconfigs, keys) in cleartext.
- `.env` or any `*.tfvars` (only `*.example*` variants are allowed).
- Real identifiers, even "non-secret" ones: subscription IDs, tenant IDs,
  principal/object IDs, storage account names, public IPs. They are not
  credentials, but repo policy keeps them out anyway - all flow in via env
  vars (see `.env.example`). Docs use the all-zeros GUID and RFC 5737 IPs
  (`203.0.113.x`) as placeholders; `.gitleaks.toml` allowlists exactly those.

## Where real values go

- Locally: `.env` (gitignored), sourced before terragrunt runs.
- CI: GitHub repository **variables** consumed by OIDC (no secrets exist).
- Kubeconfigs: `~/.kube/*.yaml`, outside the repo entirely.

## Enforcement layers (keep all of them working)

1. `githooks/pre-commit` - blocks forbidden file types + gitleaks staged scan.
2. `githooks/pre-push` - gitleaks over working tree + full history.
   (Enable: `git config core.hooksPath githooks`.)
3. `.pre-commit-config.yaml` - same checks for pre-commit-framework users.
4. CI `ci.yml` - gitleaks on every push/PR (last line of defense).
5. On demand: the `secret-scan` skill (`.claude/skills/secret-scan/`).

## For Claude specifically

- Before ANY `git commit` or `git push` in this repo, run the secret-scan
  skill (or `bash githooks/pre-push`) and act on findings.
- Never inline a real value from `az` CLI output, tool results, or `.env`
  into a tracked file - reference the env var instead.
- If a secret ever lands in a commit: STOP, tell the user, rotate the
  credential first, then rewrite history (`git filter-repo`) before pushing.
