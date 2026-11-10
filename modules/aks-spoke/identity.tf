# Workload identities of this stamp: one user-assigned identity per Kubernetes
# service account, each holding only the roles that component needs
# (docs/identity.md §2-4). Pods exchange their projected token through the
# cluster's OIDC issuer; no secret exists. Names: id-<component>-<stamp>.
#
#   external-dns      (Private) DNS Zone Contributor on the zone(s) + Reader on the zone RG(s)
#   cert-manager      DNS Zone Contributor on the public zone (DNS-01 challenges)
#   external-secrets  Key Vault Secrets User on the environment's vault
locals {
  private_dns_zone_rg_id = var.private_dns_zone_id != null ? join("/", slice(split("/", var.private_dns_zone_id), 0, 5)) : null
  public_dns_zone_rg_id  = var.public_dns_zone_id != null ? join("/", slice(split("/", var.public_dns_zone_id), 0, 5)) : null

  external_dns_roles = merge(
    var.private_dns_zone_id == null ? {} : {
      private_zone = { scope = var.private_dns_zone_id, role_definition_name = "Private DNS Zone Contributor" }
      private_rg   = { scope = local.private_dns_zone_rg_id, role_definition_name = "Reader" }
    },
    var.public_dns_zone_id == null ? {} : merge(
      { public_zone = { scope = var.public_dns_zone_id, role_definition_name = "DNS Zone Contributor" } },
      # external-dns lists zones in the resource group; one Reader per distinct RG.
      local.public_dns_zone_rg_id == local.private_dns_zone_rg_id ? {} : {
        public_rg = { scope = local.public_dns_zone_rg_id, role_definition_name = "Reader" }
      },
    ),
  )

  cert_manager_roles = var.public_dns_zone_id == null ? {} : {
    public_zone = { scope = var.public_dns_zone_id, role_definition_name = "DNS Zone Contributor" }
  }

  external_secrets_roles = var.key_vault_id == null ? {} : {
    vault = { scope = var.key_vault_id, role_definition_name = "Key Vault Secrets User" }
  }
}

module "external_dns_identity" {
  count = var.enable_external_dns_identity ? 1 : 0

  source = "../workload-identity"

  name                = "id-external-dns-${local.stamp_id}"
  location            = var.location
  resource_group_name = azurerm_resource_group.spoke.name
  oidc_issuer_url     = module.aks.oidc_issuer_profile_issuer_url
  service_account     = var.external_dns_service_account
  role_assignments    = local.external_dns_roles
  enable_telemetry    = var.enable_telemetry
  tags                = var.tags
}

module "cert_manager_identity" {
  count = var.enable_cert_manager_identity ? 1 : 0

  source = "../workload-identity"

  name                = "id-cert-manager-${local.stamp_id}"
  location            = var.location
  resource_group_name = azurerm_resource_group.spoke.name
  oidc_issuer_url     = module.aks.oidc_issuer_profile_issuer_url
  service_account     = var.cert_manager_service_account
  role_assignments    = local.cert_manager_roles
  enable_telemetry    = var.enable_telemetry
  tags                = var.tags
}

module "external_secrets_identity" {
  count = var.enable_external_secrets_identity ? 1 : 0

  source = "../workload-identity"

  name                = "id-external-secrets-${local.stamp_id}"
  location            = var.location
  resource_group_name = azurerm_resource_group.spoke.name
  oidc_issuer_url     = module.aks.oidc_issuer_profile_issuer_url
  service_account     = var.external_secrets_service_account
  role_assignments    = local.external_secrets_roles
  enable_telemetry    = var.enable_telemetry
  tags                = var.tags
}
