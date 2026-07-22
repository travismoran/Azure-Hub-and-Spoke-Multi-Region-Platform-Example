# Shared configuration for every hub unit. Leaf terragrunt.hcl files include
# this and root.hcl and nothing else - all context is read from the nearest
# env.hcl and region.hcl.

locals {
  env    = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  region = read_terragrunt_config(find_in_parent_folders("region.hcl")).locals
}

terraform {
  source = "${get_repo_root()}/modules/hub"
}

inputs = {
  environment       = local.env.environment
  location          = local.region.location
  region_short      = local.region.region_short
  address_space     = local.region.hub_address_space
  enable_firewall   = local.env.enable_firewall
  firewall_sku_tier = local.env.firewall_sku_tier
  enable_telemetry  = local.env.enable_telemetry

  tags = {
    environment = local.env.environment
    managed_by  = "terragrunt"
    project     = "azure-aks-platform"
  }
}
