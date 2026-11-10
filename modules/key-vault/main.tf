# An environment's secret store (docs/identity.md §4-5, ADR-024/025): one
# RBAC-mode Key Vault that External Secrets Operator syncs into the cluster(s)
# of that environment. Three kinds of secret live in it:
#   managed    value owned by Terraform (passed in by the caller)
#   generated  value created here with random_password (cookie secrets, ...)
#   operator   placeholder created here, real value set once by a human with
#              `az keyvault secret set`; Terraform ignores it afterwards
# Readers (Key Vault Secrets User) are granted by whoever creates the
# consuming identity: modules/aks-spoke for AKS, modules/local-cluster for a
# local cluster; plus the plan pipeline identity, which refreshes secret
# state. Writers (Secrets Officer) are the applying principal and the
# deploy pipeline identity.

data "azuread_client_config" "current" {}

data "azuread_service_principals" "officers" {
  count = length(var.officer_service_principal_names) > 0 ? 1 : 0

  display_names  = var.officer_service_principal_names
  ignore_missing = true
}

data "azuread_service_principals" "readers" {
  count = length(var.reader_service_principal_names) > 0 ? 1 : 0

  display_names  = var.reader_service_principal_names
  ignore_missing = true
}

locals {
  reader_ids = toset(try(data.azuread_service_principals.readers[0].object_ids, []))
  officer_ids = toset(concat(
    [data.azuread_client_config.current.object_id],
    try(data.azuread_service_principals.officers[0].object_ids, []),
    tolist(var.additional_officer_principal_ids),
  ))

  resource_group_name = var.create_resource_group ? azurerm_resource_group.this[0].name : var.resource_group_name
  resource_group_id   = var.create_resource_group ? azurerm_resource_group.this[0].id : "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}"

  generated_secrets = {
    for key, name in var.generated_secrets : key => {
      name         = name
      content_type = "text/plain"
      tags         = { managed_by = "terraform", source = "modules/key-vault random_password" }
    }
  }
  secrets = merge(var.managed_secrets, local.generated_secrets)
  secret_values = merge(
    var.managed_secret_values,
    { for key, _ in var.generated_secrets : key => random_password.generated[key].result },
  )

  role_assignments = merge(
    { for id in local.officer_ids : "officer-${id}" => {
      role_definition_id_or_name = "Key Vault Secrets Officer"
      principal_id               = id
      description                = "Terraform / operator writes secrets"
    } },
    # The plan pipeline refreshes azurerm_key_vault_secret state and needs read.
    { for id in local.reader_ids : "reader-${id}" => {
      role_definition_id_or_name = "Key Vault Secrets User"
      principal_id               = id
      principal_type             = "ServicePrincipal"
      description                = "Terraform plan reads secret metadata"
    } },
    { for key, p in var.secrets_user_principals : key => {
      role_definition_id_or_name = "Key Vault Secrets User"
      principal_id               = p.principal_id
      principal_type             = p.principal_type
      description                = p.description
    } },
  )
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "this" {
  count = var.create_resource_group ? 1 : 0

  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "random_password" "generated" {
  for_each = var.generated_secrets

  length  = 32 # oauth2-proxy and friends accept 16, 24 or 32 bytes
  special = false
}

module "key_vault" {
  source = "git::https://github.com/Azure/terraform-azurerm-avm-res-keyvault-vault.git?ref=7c53adbc7f4f716fa00b21af90e1a120db5e19ef" # v0.13.0

  name             = var.name
  location         = var.location
  parent_id        = local.resource_group_id
  tenant_id        = data.azuread_client_config.current.tenant_id
  sku_name         = "standard"
  enable_telemetry = var.enable_telemetry
  tags             = var.tags

  # RBAC data plane (no access policies). Reachable from the internet and
  # protected by RBAC + Entra: AKS nodes and laptops have no stable egress IP
  # at this stage; private endpoints are a per-environment follow-up.
  legacy_access_policies_enabled = false
  public_network_access_enabled  = true
  network_acls                   = null
  purge_protection_enabled       = var.purge_protection_enabled
  soft_delete_retention_days     = var.soft_delete_retention_days

  role_assignments = local.role_assignments
  secrets          = local.secrets
  secrets_value    = local.secret_values

  # Role assignments take up to ~30 s to propagate before the applying
  # principal can write the secrets above.
  wait_for_rbac_before_secret_operations = {
    create = "60s"
  }

  depends_on = [azurerm_resource_group.this]
}

# Placeholders whose real value an operator sets once; `value` is ignored so
# a manual update (new secret version) is never drift and never overwritten.
# They go with the vault on destroy (soft delete keeps them recoverable), so
# no prevent_destroy.
# tflint-ignore: azurerm_resources_missing_prevent_destroy
resource "azurerm_key_vault_secret" "operator_managed" {
  for_each = toset(var.operator_managed_secret_names)

  name         = each.key
  key_vault_id = module.key_vault.resource_id
  value        = "REPLACE_ME"
  content_type = "operator-managed: set the real value with `az keyvault secret set`"
  tags         = merge(var.tags, { managed_by = "operator", consumer = "external-secrets" })

  lifecycle {
    ignore_changes = [value, content_type, tags, not_before_date, expiration_date]
  }

  # The module returns after its own RBAC wait, so the applying principal can write here.
  depends_on = [module.key_vault]
}
