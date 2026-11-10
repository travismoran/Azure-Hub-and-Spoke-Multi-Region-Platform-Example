# DNS credentials for clusters that run outside Azure (docs/identity.md §5):
# one Entra application + service principal per external environment, able
# to write exactly that environment's public zone.
#
# A cluster outside Azure has no managed identity and (without Azure Arc) no
# OIDC issuer Entra can trust, so a client secret is the only credential
# external-dns and cert-manager can use - neither supports certificates.
# The secret is the documented exception to the no-secret rule: created and
# rotated here, held in state and read out with `terragrunt output`, copied
# into the cluster by <gitops-repo>/scripts, never committed.
#
# Roles, per environment, both built-in and scoped to the zone's resources:
#   DNS Zone Contributor  on <env>.<parent_zone>   (A/TXT records, ACME challenges)
#   Reader                on the zones' RG         (external-dns lists zones in the RG)

locals {
  envs = var.enabled ? toset(keys(var.zone_ids)) : toset([])

  # /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/dnszones/<zone>
  zone_parts      = { for env, id in var.zone_ids : env => split("/", id) }
  subscription_id = { for env, p in local.zone_parts : env => p[2] }
  resource_group  = { for env, p in local.zone_parts : env => p[4] }
  zone_rg_id      = { for env, p in local.zone_parts : env => join("/", slice(p, 0, 5)) }
  zone_name       = { for env, p in local.zone_parts : env => element(p, length(p) - 1) }
}

data "azuread_client_config" "current" {}

# Pipeline identities that must be able to manage these apps later with only
# Application.ReadWrite.OwnedBy (docs/github-oidc-setup.md). ignore_missing:
# a fresh tenant without the pipeline apps still validates and applies.
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

module "principal" {
  for_each = local.envs

  source = "../service-principal"

  display_name         = "${var.name_prefix}-${each.key}"
  description          = "external-dns + cert-manager DNS-01 for the ${each.key} environment: writes ${local.zone_name[each.key]} only"
  owner_object_ids     = local.owners
  secret_rotation_days = var.secret_rotation_days
  secret_display_name  = "external-dns+cert-manager"
}

# principal_type avoids the replication race right after SP creation
# ("PrincipalNotFound") by letting ARM accept the not-yet-replicated object.
resource "azurerm_role_assignment" "zone_contributor" {
  for_each = local.envs

  scope                = var.zone_ids[each.key]
  role_definition_name = "DNS Zone Contributor"
  principal_id         = module.principal[each.key].object_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "zone_rg_reader" {
  for_each = local.envs

  scope                = local.zone_rg_id[each.key]
  role_definition_name = "Reader"
  principal_id         = module.principal[each.key].object_id
  principal_type       = "ServicePrincipal"
}
