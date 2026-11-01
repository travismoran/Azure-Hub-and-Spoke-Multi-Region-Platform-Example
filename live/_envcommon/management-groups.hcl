# Shared configuration for the tenant-level management-groups unit
# (live/platform/management-groups): the landing-zone hierarchy and which
# subscription sits where. Deploys via the management subscription; the
# resources themselves are tenant-scoped.

locals {
  platform = read_terragrunt_config(find_in_parent_folders("platform.hcl")).locals
}

terraform {
  source = "${get_repo_root()}/modules/management-groups"
}

inputs = {
  enabled       = local.platform.enable_management_groups
  name_prefix   = local.platform.name_prefix
  environments  = local.platform.environments
  subscriptions = local.platform.subscriptions
}
