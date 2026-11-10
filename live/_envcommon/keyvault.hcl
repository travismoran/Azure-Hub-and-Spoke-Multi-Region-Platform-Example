# Shared configuration for an environment's Key Vault unit (live/<env>/keyvault):
# the single secret store every cluster of the environment syncs from through
# External Secrets Operator (modules/key-vault, ADR-025). Lives in the
# environment's subscription, in its first region. Readers are the stamps'
# external-secrets identities, granted by aks-spoke; this unit only creates
# the vault, the generated secrets and the operator placeholders.

locals {
  env      = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  platform = read_terragrunt_config("${dirname(find_in_parent_folders("root.hcl"))}/platform/platform.hcl").locals
  common   = read_terragrunt_config(find_in_parent_folders("root.hcl")).locals
  region   = read_terragrunt_config("${dirname(find_in_parent_folders("env.hcl"))}/${local.env.regions[0]}/region.hcl").locals
}

terraform {
  source = "${get_repo_root()}/modules/key-vault"
}

inputs = {
  name                  = "kv-${local.env.name_prefix}-${local.env.environment}"
  resource_group_name   = "rg-${local.env.name_prefix}-${local.env.environment}-secrets"
  create_resource_group = true
  location              = local.region.location

  officer_service_principal_names = local.platform.dns_principal_owner_sp_names
  generated_secrets               = { oauth2_proxy_cookie_secret = "oauth2-proxy-cookie-secret" }
  operator_managed_secret_names   = ["google-oauth-client-id", "google-oauth-client-secret"]
  purge_protection_enabled        = local.env.key_vault_purge_protection
  soft_delete_retention_days      = local.env.key_vault_soft_delete_days

  tags = merge(local.common.common_tags, { Environment = local.env.environment })
}
