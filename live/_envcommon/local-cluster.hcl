# Shared configuration for a local-cluster unit (live/<env-subscription>/<env>/local-cluster):
# the Azure footprint of an external environment (platform.hcl
# external_environments) - resource group, Key Vault and the External Secrets
# Operator principal that reads it (docs/identity.md §5, ADR-024). Lives in
# the subscription of the live/<env> folder it sits under (dev for
# live/dev/local). Depends on live/platform/dns-principals so the DNS
# credentials land in the vault and reach the cluster through ESO.

locals {
  env      = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  platform = read_terragrunt_config("${dirname(find_in_parent_folders("root.hcl"))}/platform/platform.hcl").locals
  common   = read_terragrunt_config(find_in_parent_folders("root.hcl")).locals

  # The external environment's name is the folder above the unit.
  external_env = basename(dirname(get_original_terragrunt_dir()))
}

terraform {
  source = "${get_repo_root()}/modules//local-cluster" # double slash: copy all of modules/ so ../service-principal resolves
}

dependency "dns_principals" {
  config_path = "../../../platform/dns-principals"

  # Shape must match modules/public-dns-principals/outputs.tf exactly. Empty
  # maps = no DNS secrets yet (they are skipped until that unit is applied).
  mock_outputs = {
    azure_json            = {}
    client_ids            = {}
    client_secrets        = {}
    object_ids            = {}
    secret_end_dates      = {}
    tenant_id             = null
    zone_names            = {}
    zone_resource_groups  = {}
    zone_subscription_ids = {}
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  environment = local.external_env
  location    = local.platform.avnm_location
  name_prefix = local.env.name_prefix

  dns_secrets_present = contains(keys(dependency.dns_principals.outputs.client_ids), local.external_env)
  dns_azure_json      = lookup(dependency.dns_principals.outputs.azure_json, local.external_env, "")
  dns_sp_secret       = lookup(dependency.dns_principals.outputs.client_secrets, local.external_env, "")

  secret_rotation_days          = local.platform.dns_principal_secret_days
  owner_service_principal_names = local.platform.dns_principal_owner_sp_names

  # Container registry for the cluster's images (ADR-026): Basic SKU, one
  # GitHub Actions push identity per source repository, a read-only pull
  # token in the vault. subject_prefix is the repository's immutable OIDC
  # subject prefix (`gh api repos/<owner>/<repo>/actions/oidc/customization/sub`),
  # an identifier that stays out of Git like every other one: TG_OIDC_SUBJECT_PREFIX_<REPO>.
  enable_acr = true
  acr_push_repositories = {
    app_a = {
      repository     = "your-org/app-a"
      subject_prefix = get_env("TG_OIDC_SUBJECT_PREFIX_APP_A", "")
      subjects       = ["ref:refs/heads/master"]
    }
    # One identity for the repo; its ci workflow pushes two images under the
    # app-b/ namespace, which is why the pull list is spelled out below.
    app_b = {
      repository     = "your-org/app-b"
      subject_prefix = get_env("TG_OIDC_SUBJECT_PREFIX_APP_B", "")
      subjects       = ["ref:refs/heads/main"]
    }
  }
  # Repositories the cluster's read-only pull token may read (default would be
  # the keys above; app-b publishes app-b/api and app-b/worker).
  acr_pull_repositories = ["app-a", "app-b/api", "app-b/worker"]

  tags = merge(local.common.common_tags, { Environment = local.external_env })
}
