# Root terragrunt configuration, inherited by every unit via include "root".
#
# All Azure context comes from environment variables so that nothing
# account-specific is ever committed to this public repository:
#   ARM_SUBSCRIPTION_ID / ARM_TENANT_ID  - azurerm provider auth context
#   TG_STATE_RESOURCE_GROUP              - resource group of the state storage account
#   TG_STATE_STORAGE_ACCOUNT             - state storage account (globally unique)
# See .env.example at the repo root.

locals {
  state_resource_group  = get_env("TG_STATE_RESOURCE_GROUP", "")
  state_storage_account = get_env("TG_STATE_STORAGE_ACCOUNT", "")

  # When the state env vars are unset (fresh clone, offline CI validation),
  # fall back to a throwaway local backend inside .terragrunt-cache so that
  # init/validate/plan-with-mocks work without any Azure access. Anything
  # real must set TG_STATE_* - see .env.example.
  use_azurerm_backend = local.state_storage_account != ""
}

remote_state {
  backend = local.use_azurerm_backend ? "azurerm" : "local"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = local.use_azurerm_backend ? {
    resource_group_name  = local.state_resource_group
    storage_account_name = local.state_storage_account
    container_name       = "tfstate"
    key                  = "${path_relative_to_include()}/terraform.tfstate"
    # RBAC (Entra ID) auth only - no storage account keys anywhere.
    use_azuread_auth = true
    } : {
    path = "terraform.tfstate"
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "azurerm" {
  features {}
  # subscription_id / tenant_id come from ARM_SUBSCRIPTION_ID / ARM_TENANT_ID.
  # azurerm 4.x has no default-subscription fallback, so these are mandatory.
  resource_provider_registrations = "none"
  storage_use_azuread             = true
}
EOF
}
