# Shared configuration for the per-environment platform-network unit (AVNM +
# IPAM pools + global mesh + security admin). One unit per environment at
# live/<env>/platform-network; every aks-spoke of the environment depends on
# it for its IPAM pool ID.
#
# Region data stays in each region.hcl (single source of CIDRs); env.hcl only
# lists which region folders exist.

locals {
  env     = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  env_dir = dirname(find_in_parent_folders("env.hcl"))

  region_cfgs = [for r in local.env.regions : read_terragrunt_config("${local.env_dir}/${r}/region.hcl").locals]
  regions = {
    for c in local.region_cfgs : c.region_short => {
      location          = c.location
      stamp_pool_prefix = c.stamp_pool_prefix
      hub_address_space = c.hub_address_space
    }
  }
}

terraform {
  source = "${get_repo_root()}/modules/platform-network"
}

inputs = {
  enabled     = local.env.enable_avnm
  environment = local.env.environment
  location    = local.env.avnm_location
  regions     = local.regions

  security_admin_deny_inbound_from = local.env.security_admin_deny_inbound_from

  tags = {
    environment = local.env.environment
    managed_by  = "terragrunt"
    project     = "azure-aks-platform"
  }
}
