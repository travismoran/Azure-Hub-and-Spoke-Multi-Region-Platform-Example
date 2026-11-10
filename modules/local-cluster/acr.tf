# Container registry for the images the local cluster runs (ADR-026).
#   cr<prefix><env>                 Basic SKU: the cheapest tier (~$5/month, 10 GB)
#   id-gh-<repo>-<env>              one managed identity per source repository,
#                                   assumed by its GitHub Actions through OIDC
#                                   (modules/github-actions-identity), AcrPush
#                                   on this registry only
#   token acr-pull-<env>            repository-scoped ACR token (read-only, the
#                                   listed repositories) for the cluster's
#                                   imagePullSecret; its password goes into
#                                   the vault, External Secrets syncs it in
# Entra RBAC cannot be scoped below the registry and a cluster outside Azure
# has no managed identity, which is why pull uses an ACR token (native to
# every tier) rather than a third service principal.

locals {
  acr_name              = coalesce(var.acr_name, "cr${var.name_prefix}${var.environment}")
  acr_pull_repositories = var.acr_pull_repositories != null ? var.acr_pull_repositories : sort(keys(var.acr_push_repositories))
  acr_pull_token_name   = "acr-pull-${var.environment}"
}

# tflint-ignore: azurerm_resources_missing_prevent_destroy
resource "azurerm_container_registry" "this" {
  count = var.enable_acr ? 1 : 0

  name                = local.acr_name
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = var.acr_sku
  tags                = var.tags

  # Identity-only access: no admin user, no anonymous pull. Basic has no
  # network rules or private endpoints; the data plane is RBAC + tokens.
  admin_enabled          = false
  anonymous_pull_enabled = false
}

# --- Push: GitHub Actions of each source repository ---------------------------

module "push_identity" {
  for_each = var.enable_acr ? var.acr_push_repositories : {}

  source = "../github-actions-identity"

  name                = "id-gh-${each.key}-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  repository          = each.value.repository
  subject_prefix      = each.value.subject_prefix
  subjects            = each.value.subjects
  enable_telemetry    = var.enable_telemetry
  tags                = var.tags

  role_assignments = {
    acr_push = {
      scope                = azurerm_container_registry.this[0].id
      role_definition_name = "AcrPush"
      description          = "GitHub Actions of ${each.value.repository} push images to ${local.acr_name}"
    }
  }
}

# --- Pull: repository-scoped token for the cluster ----------------------------

resource "azurerm_container_registry_scope_map" "pull" {
  count = var.enable_acr && length(local.acr_pull_repositories) > 0 ? 1 : 0

  name                    = "pull-${var.environment}"
  description             = "Read-only pull of the ${var.environment} cluster's images"
  container_registry_name = azurerm_container_registry.this[0].name
  resource_group_name     = azurerm_resource_group.this.name

  actions = flatten([
    for repo in local.acr_pull_repositories : [
      "repositories/${repo}/content/read",
      "repositories/${repo}/metadata/read",
    ]
  ])
}

resource "azurerm_container_registry_token" "pull" {
  count = length(azurerm_container_registry_scope_map.pull)

  name                    = local.acr_pull_token_name
  container_registry_name = azurerm_container_registry.this[0].name
  resource_group_name     = azurerm_resource_group.this.name
  scope_map_id            = azurerm_container_registry_scope_map.pull[0].id
  enabled                 = true
}

# Same rotation shape as the service principals: the password is replaced on
# the first apply after the period elapses; the old one is valid until then.
resource "time_rotating" "acr_pull" {
  count = length(azurerm_container_registry_scope_map.pull)

  rotation_days = var.secret_rotation_days
}

resource "azurerm_container_registry_token_password" "pull" {
  count = length(azurerm_container_registry_scope_map.pull)

  container_registry_token_id = azurerm_container_registry_token.pull[0].id

  password1 {
    expiry = time_rotating.acr_pull[0].rotation_rfc3339
  }
}

locals {
  # Vault secrets for the imagePullSecret. Keys depend only on non-sensitive
  # toggles so the key-vault module's for_each is known at plan time.
  acr_secrets_present = var.enable_acr && length(local.acr_pull_repositories) > 0
  acr_secrets = local.acr_secrets_present ? {
    acr_login_server = {
      name         = "acr-login-server"
      content_type = "text/plain"
      tags         = { consumer = "imagePullSecret/.dockerconfigjson", source = "modules/local-cluster acr.tf" }
    }
    acr_pull_username = {
      name         = "acr-pull-username"
      content_type = "text/plain"
      tags         = { consumer = "imagePullSecret/.dockerconfigjson", source = "modules/local-cluster acr.tf" }
    }
    acr_pull_password = {
      name         = "acr-pull-password"
      content_type = "text/plain"
      tags         = { consumer = "imagePullSecret/.dockerconfigjson", source = "modules/local-cluster acr.tf" }
    }
  } : {}
  acr_secret_values = local.acr_secrets_present ? {
    acr_login_server  = azurerm_container_registry.this[0].login_server
    acr_pull_username = azurerm_container_registry_token.pull[0].name
    acr_pull_password = azurerm_container_registry_token_password.pull[0].password1[0].value
  } : {}
}
