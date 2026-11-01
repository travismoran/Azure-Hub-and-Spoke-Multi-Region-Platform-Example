# Shared configuration for the tenant-level network platform unit
# (live/platform/network): one AVNM at the top management group, IPAM pool
# hierarchy, one network group + mesh per environment, security admin
# rules. Every aks-spoke depends on it for its IPAM pool ID.
#
# CIDRs stay in each live/<env>/<region>/region.hcl (single source); env.hcl
# says which region folders exist and whether the environment is in AVNM;
# platform.hcl lists the environments and the regional root pools.

locals {
  platform = read_terragrunt_config(find_in_parent_folders("platform.hcl")).locals
  live_dir = dirname(find_in_parent_folders("root.hcl"))

  env_cfgs = { for e in local.platform.environments : e => read_terragrunt_config("${local.live_dir}/${e}/env.hcl").locals }
  region_cfgs = {
    for e, cfg in local.env_cfgs : e => [for r in cfg.regions : read_terragrunt_config("${local.live_dir}/${e}/${r}/region.hcl").locals]
  }

  environments = {
    for e, cfg in local.env_cfgs : e => {
      enabled = cfg.enable_avnm
      regions = {
        for rc in local.region_cfgs[e] : rc.region_short => {
          stamp_pool_prefix = rc.stamp_pool_prefix
          hub_address_space = rc.hub_address_space
        }
      }
    }
  }

  # The platform exists as soon as one environment opts in.
  enabled = anytrue([for e in local.environments : e.enabled])
}

terraform {
  source = "${get_repo_root()}/modules/platform-network"
}

dependency "management_groups" {
  config_path = "../management-groups"

  # Shape must match modules/management-groups/outputs.tf exactly. Null top
  # MG = subscription scope, which is also what enable_management_groups =
  # false yields.
  mock_outputs = {
    management_group_ids    = {}
    subscription_placement  = {}
    top_management_group_id = null
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  enabled             = local.enabled
  location            = local.platform.avnm_location
  management_group_id = dependency.management_groups.outputs.top_management_group_id
  regions             = local.platform.regions
  environments        = local.environments

  tags = {
    managed_by = "terragrunt"
    project    = "azure-aks-platform"
  }
}
