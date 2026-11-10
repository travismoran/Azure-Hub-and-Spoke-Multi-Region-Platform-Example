# Shared configuration for every hub unit. Leaf terragrunt.hcl files include
# this and root.hcl and nothing else - all context is read from the nearest
# env.hcl and region.hcl.

locals {
  env    = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  region = read_terragrunt_config(find_in_parent_folders("region.hcl")).locals
  common = read_terragrunt_config(find_in_parent_folders("root.hcl")).locals
}

terraform {
  source = "${get_repo_root()}/modules/hub"
}

# Only for the environment's central private DNS zone ID (enable_private_dns).
# Shape must match modules/platform-network/outputs.tf exactly.
dependency "platform_network" {
  config_path = "../../../platform/network"

  mock_outputs = {
    ipam_pool_ids        = {}
    ipam_pool_prefixes   = {}
    network_group_ids    = {}
    network_manager_id   = null
    private_dns_zone_ids = {}
    root_pool_ids        = {}
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  environment       = local.env.environment
  location          = local.region.location
  region_short      = local.region.region_short
  address_space     = local.region.hub_address_space
  enable_firewall   = local.env.enable_firewall
  firewall_sku_tier = local.env.firewall_sku_tier
  enable_telemetry  = local.env.enable_telemetry

  # Stamps egress through this firewall -> it needs the AKS egress rules.
  aks_egress_via_firewall = local.env.aks_outbound_type == "userDefinedRouting"

  # Optional hub services (env.hcl toggles, all default off).
  enable_dns_resolver = local.env.enable_dns_resolver
  enable_bastion      = local.env.enable_bastion
  bastion_sku         = local.env.bastion_sku
  private_dns_zone_id = local.env.enable_private_dns ? lookup(dependency.platform_network.outputs.private_dns_zone_ids, local.env.environment, null) : null

  tags = merge(local.common.common_tags, { Environment = local.env.environment })
}
