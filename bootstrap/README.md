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
- In the multi-subscription layout the state lives in the *management*
  subscription (`TG_SUBSCRIPTION_MANAGEMENT`, which defaults to
  `ARM_SUBSCRIPTION_ID`); every unit in every other subscription writes its
  state there (`subscription_id` in the backend config, Entra auth).

`register-providers.sh` is the other bootstrap step: it registers the
resource providers the platform needs in every subscription named by
`ARM_SUBSCRIPTION_ID` / `TG_SUBSCRIPTION_*`. Re-run it whenever a
subscription is added (e.g. `TG_SUBSCRIPTION_PROD`).
