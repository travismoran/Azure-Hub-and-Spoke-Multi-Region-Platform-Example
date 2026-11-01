# Root terragrunt configuration, inherited by every unit via include "root".
#
# All Azure context comes from environment variables so that nothing
# account-specific is ever committed to this public repository (see
# .env.example):
#   ARM_TENANT_ID                         tenant
#   ARM_SUBSCRIPTION_ID                   default / fallback subscription
#   TG_SUBSCRIPTION_MANAGEMENT            state storage (+ management groups unit)
#   TG_SUBSCRIPTION_CONNECTIVITY          hubs + the network platform (AVNM)
#   TG_SUBSCRIPTION_<ENV>                 that environment's AKS stamps
#   TG_STATE_RESOURCE_GROUP / _ACCOUNT    state storage account (in management)
#
# Single-subscription mode: set only ARM_SUBSCRIPTION_ID and every unit
# lands in it. See docs/subscriptions.md.

locals {
  state_resource_group  = get_env("TG_STATE_RESOURCE_GROUP", "")
  state_storage_account = get_env("TG_STATE_STORAGE_ACCOUNT", "")

  # When the state env vars are unset (fresh clone, offline CI validation),
  # fall back to a throwaway local backend inside .terragrunt-cache so that
  # init/validate/plan-with-mocks work without any Azure access. Anything
  # real must set TG_STATE_* - see .env.example.
  use_azurerm_backend = local.state_storage_account != ""

  default_subscription    = get_env("ARM_SUBSCRIPTION_ID", "")
  management_subscription = get_env("TG_SUBSCRIPTION_MANAGEMENT", local.default_subscription)

  # --- Subscription placement -------------------------------------------
  # Which subscription each kind of unit deploys into, decided from the
  # unit's path (e.g. "dev/westus3/aks-spoke", "platform/network"):
  #   management-groups  -> management     (tenant-level resources; any sub works)
  #   network (platform) -> connectivity   (AVNM, IPAM pools)
  #   hub                -> connectivity   (hub VNets, firewalls; all envs)
  #   aks-spoke          -> TG_SUBSCRIPTION_<ENV> (the environment's stamps)
  # Unset variables fall back to ARM_SUBSCRIPTION_ID; all unset means the
  # provider block carries no subscription (offline validation only).
  unit_path = path_relative_to_include()
  unit_env  = split("/", local.unit_path)[0]
  unit_name = basename(local.unit_path)

  subscription_by_unit = {
    management-groups = local.management_subscription
    network           = get_env("TG_SUBSCRIPTION_CONNECTIVITY", local.default_subscription)
    hub               = get_env("TG_SUBSCRIPTION_CONNECTIVITY", local.default_subscription)
    aks-spoke         = get_env("TG_SUBSCRIPTION_${upper(local.unit_env)}", local.default_subscription)
  }
  subscription_id = lookup(local.subscription_by_unit, local.unit_name, local.default_subscription)
}

remote_state {
  backend = local.use_azurerm_backend ? "azurerm" : "local"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = local.use_azurerm_backend ? {
    subscription_id      = local.management_subscription
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
  # tenant_id comes from ARM_TENANT_ID. azurerm 4.x has no default-subscription
  # fallback; the subscription is chosen per unit by live/root.hcl.
%{if local.subscription_id != ""~}
  subscription_id = "${local.subscription_id}"
%{endif~}
  resource_provider_registrations = "none"
  storage_use_azuread             = true
}
EOF
}
