# Rule: terraform / terragrunt changes

- After editing `modules/**`: `terraform -chdir=modules/<m> init -backend=false
  && terraform -chdir=modules/<m> validate`, then `terraform fmt -recursive`.
- After editing `live/**`: `terragrunt hcl fmt` and, from `live/`,
  `terragrunt run --all -- validate` (works offline when `TG_STATE_*` unset).
- Hub outputs are a cross-stack contract: any change to
  `modules/hub/outputs.tf` MUST be mirrored in the `mock_outputs` blocks in
  `live/_envcommon/aks-spoke.hcl` and `live/dev/eastus2/hub/terragrunt.hcl`.
  Same for `modules/platform-network/outputs.tf` → the `platform_network`
  mock_outputs in `live/_envcommon/aks-spoke.hcl`, and
  `modules/management-groups/outputs.tf` → the `management_groups`
  mock_outputs in `live/_envcommon/platform-network.hcl`.
- `live/platform/network` is an external dependency of every spoke: apply
  `live/platform` first, then `live/<env>` (or `--queue-include-external`).
- Subscription placement lives only in `live/root.hcl` (unit path →
  `TG_SUBSCRIPTION_*`); never hardcode a subscription in a module or leaf.
- Renders with placeholder IDs are the way to check placement offline:
  `TG_SUBSCRIPTION_DEV=00000000-... terragrunt render --format json`.
- Plans against real Azure must be reviewed before apply; never apply prod.
- New AVM module inputs: read the module's actual `variables.tf` at the
  pinned tag first - optional-attr defaults often don't survive conditional
  expressions, and several AVM modules dereference nested objects without
  null guards.
- Record every non-obvious design choice as an ADR in
  `.ai/status/decisions-adr.md`, and log test evidence under
  `.ai/test-results/`.
