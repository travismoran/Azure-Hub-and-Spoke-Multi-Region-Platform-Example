# Azure footprint of a cluster that runs outside Azure (docs/identity.md §5,
# ADR-024): a resource group, the environment's Key Vault (modules/key-vault)
# and the one credential the cluster needs to read it. Everything else the
# cluster needs (DNS credentials, OAuth client, cookie secrets) is a vault
# secret synced in by External Secrets Operator.
#
#   rg-<prefix>-<env>
#   └── kv-<prefix>-<env>          RBAC authorization, soft delete
#       ├── external-dns-azure-json            from live/platform/dns-principals
#       ├── cert-manager-azuredns-client-secret   "
#       ├── oauth2-proxy-cookie-secret         generated
#       └── google-oauth-client-id / -secret   placeholders; value set by an operator
#   sp-eso-<env>                   Key Vault Secrets User on the vault only

locals {
  resource_group_name = coalesce(var.resource_group_name, "rg-${var.name_prefix}-${var.environment}")
  key_vault_name      = coalesce(var.key_vault_name, "kv-${var.name_prefix}-${var.environment}")
}

data "azuread_client_config" "current" {}

data "azuread_service_principals" "owners" {
  count = length(var.owner_service_principal_names) > 0 ? 1 : 0

  display_names  = var.owner_service_principal_names
  ignore_missing = true
}

locals {
  owners = toset(concat(
    [data.azuread_client_config.current.object_id],
    try(data.azuread_service_principals.owners[0].object_ids, []),
  ))
}

resource "azurerm_resource_group" "this" {
  name     = local.resource_group_name
  location = var.location
  tags     = var.tags
}

# --- The cluster's identity for reading secrets -----------------------------

module "eso_principal" {
  source = "../service-principal"

  display_name         = "sp-eso-${var.environment}"
  description          = "External Secrets Operator on the ${var.environment} cluster: reads secrets from ${local.key_vault_name} only"
  owner_object_ids     = local.owners
  secret_rotation_days = var.secret_rotation_days
  secret_display_name  = "external-secrets"
}

# --- Key Vault ----------------------------------------------------------------

locals {
  # DNS credentials appear once live/platform/dns-principals has been applied
  # for this environment (dns_secrets_present). Map keys must be known at plan
  # time and may not derive from sensitive values.
  dns_secrets = var.dns_secrets_present ? {
    external_dns_azure_json = {
      name         = "external-dns-azure-json"
      content_type = "application/json"
      tags         = { consumer = "external-dns/azure-config-file", source = "live/platform/dns-principals" }
    }
    cert_manager_azuredns_sp_secret = {
      name         = "cert-manager-azuredns-client-secret"
      content_type = "text/plain"
      tags         = { consumer = "cert-manager/azuredns-sp", source = "live/platform/dns-principals" }
    }
  } : {}
}

module "vault" {
  source = "../key-vault"

  name                  = local.key_vault_name
  location              = var.location
  resource_group_name   = azurerm_resource_group.this.name
  create_resource_group = false
  enable_telemetry      = var.enable_telemetry
  tags                  = var.tags

  officer_service_principal_names = var.owner_service_principal_names
  reader_service_principal_names  = var.reader_service_principal_names
  secrets_user_principals = {
    eso = {
      principal_id   = module.eso_principal.object_id
      principal_type = "ServicePrincipal"
      description    = "External Secrets Operator on the ${var.environment} cluster"
    }
  }

  managed_secrets = merge(local.dns_secrets, local.acr_secrets)
  managed_secret_values = merge({
    external_dns_azure_json         = var.dns_azure_json
    cert_manager_azuredns_sp_secret = var.dns_sp_secret
  }, local.acr_secret_values)
  generated_secrets             = { oauth2_proxy_cookie_secret = "oauth2-proxy-cookie-secret" }
  operator_managed_secret_names = var.operator_managed_secret_names

  purge_protection_enabled   = var.purge_protection_enabled
  soft_delete_retention_days = var.soft_delete_retention_days
}

