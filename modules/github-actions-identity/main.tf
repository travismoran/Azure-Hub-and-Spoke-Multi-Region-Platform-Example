# One identity for a GitHub repository's workflows (docs/identity.md §1 tier
# 2, §4): a user-assigned managed identity that GitHub Actions assumes through
# OIDC federation - no secret anywhere. One federated credential per subject
# (branch, tag, environment or pull_request) and the narrow roles the
# workflows need (AcrPush on one registry, ...). Mirrors modules/workload-
# identity for clusters. Name convention: id-gh-<repo>-<environment>.
#
# GitHub signs tokens with subject "<prefix>:<subject>". Repositories created
# or transferred into an organisation since 2025 use immutable subjects whose
# prefix carries the owner and repository IDs (repo:<owner>@<id>/<repo>@<id>);
# read it with `gh api repos/<owner>/<repo>/actions/oidc/customization/sub`
# and pass it as subject_prefix. Federated credentials are matched exactly, so
# a wrong prefix fails only at token exchange (AADSTS700213).

locals {
  subject_prefix = var.subject_prefix != null && var.subject_prefix != "" ? var.subject_prefix : "repo:${var.repository}"

  # Credential names: 3-120 chars of [A-Za-z0-9-_].
  federated_credentials = {
    for s in var.subjects : replace(replace(replace(s, "/", "-"), ":", "-"), ".", "-") => {
      name     = substr("github-${replace(replace(replace(s, "/", "-"), ":", "-"), ".", "-")}", 0, 120)
      issuer   = "https://token.actions.githubusercontent.com"
      subject  = "${local.subject_prefix}:${s}"
      audience = ["api://AzureADTokenExchange"]
    }
  }
}

module "identity" {
  source = "git::https://github.com/Azure/terraform-azurerm-avm-res-managedidentity-userassignedidentity.git?ref=7a0c461789f0177a0b666378924cd5d33196ef8a" # v0.6.0

  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  enable_telemetry    = var.enable_telemetry
  tags                = var.tags

  federated_identity_credentials = local.federated_credentials
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
