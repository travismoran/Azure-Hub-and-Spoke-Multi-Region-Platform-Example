# One workload identity = one user-assigned managed identity bound 1:1 to a
# Kubernetes service account through a federated credential on the cluster's
# OIDC issuer, plus the roles that service account needs (docs/identity.md
# §2-3). No secret exists anywhere; pods exchange their projected token for
# an Entra token. Name convention: id-<component>-<cluster>.

locals {
  sa_parts     = split("/", var.service_account)
  sa_namespace = local.sa_parts[0]
  sa_name      = local.sa_parts[1]
}

module "identity" {
  source = "git::https://github.com/Azure/terraform-azurerm-avm-res-managedidentity-userassignedidentity.git?ref=7a0c461789f0177a0b666378924cd5d33196ef8a" # v0.6.0

  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  enable_telemetry    = var.enable_telemetry
  tags                = var.tags

  federated_identity_credentials = {
    service_account = {
      name     = "${local.sa_namespace}-${local.sa_name}"
      issuer   = var.oidc_issuer_url
      subject  = "system:serviceaccount:${local.sa_namespace}:${local.sa_name}"
      audience = ["api://AzureADTokenExchange"]
    }
  }
}

# principal_type lets ARM accept the identity before replication completes.
resource "azurerm_role_assignment" "this" {
  for_each = var.role_assignments

  scope                = each.value.scope
  role_definition_name = each.value.role_definition_name
  principal_id         = module.identity.principal_id
  principal_type       = "ServicePrincipal"
  description          = each.value.description
}
