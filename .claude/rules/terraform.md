# Rule: terraform / terragrunt changes

- After editing `modules/**`: `terraform -chdir=modules/<m> init -backend=false
  && terraform -chdir=modules/<m> validate`, then `terraform fmt -recursive`.
- After editing `live/**`: `terragrunt hcl fmt` and, from `live/`,
  `terragrunt run --all -- validate` (works offline when `TG_STATE_*` unset).
- Hub outputs are a cross-stack contract: any change to
  `modules/hub/outputs.tf` MUST be mirrored in the `mock_outputs` blocks in
  `live/_envcommon/aks-spoke.hcl` and `live/dev/eastus2/hub/terragrunt.hcl`.
- Plans against real Azure must be reviewed before apply; never apply prod.
- New AVM module inputs: read the module's actual `variables.tf` at the
  pinned tag first - optional-attr defaults often don't survive conditional
  expressions, and several AVM modules dereference nested objects without
  null guards.
- Record every non-obvious design choice as an ADR in
  `.ai/status/decisions-adr.md`, and log test evidence under
  `.ai/test-results/`.
