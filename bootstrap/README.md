# State bootstrap

Terraform needs somewhere to keep state before it can manage anything, so
this one storage account is created with the `az` CLI instead of Terraform
(avoiding the chicken-and-egg problem of state for the state).

```bash
az login
cp ../.env.example ../.env   # edit with your values
source ../.env
./bootstrap-state.sh
```

Notes:

- **Storage account names are globally unique** across all of Azure, which is
  why the name comes from the `TG_STATE_STORAGE_ACCOUNT` env var and is never
  committed to this public repo.
- Shared-key access is disabled; everything (including Terraform's backend)
  authenticates with Entra ID RBAC (`use_azuread_auth = true` in
  `live/root.hcl`). The script grants the signed-in user - and optionally the
  CI app registration - `Storage Blob Data Contributor`.
- Versioning + 14-day soft delete protect against accidental state
  deletion/corruption.
- Cost: effectively zero (Standard_LRS, a few KB of blobs).
