# Shared configuration for every aks-spoke unit.

locals {
  env    = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  region = read_terragrunt_config(find_in_parent_folders("region.hcl")).locals
}

terraform {
  source = "${get_repo_root()}/modules/aks-spoke"
}

dependency "hub" {
  config_path = "../hub"

  # Mocks let init/validate/plan run before the hub exists (fresh clone, CI).
  # Shape must match modules/hub/outputs.tf exactly.
  mock_outputs = {
    firewall_private_ip = null
    location            = "mockregion"
    resource_group_name = "mock-rg-hub"
    vnet_id             = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg-hub/providers/Microsoft.Network/virtualNetworks/mock-vnet-hub"
    vnet_name           = "mock-vnet-hub"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  environment  = local.env.environment
  location     = local.region.location
  region_short = local.region.region_short
  name_prefix  = local.env.name_prefix

  spoke_address_space     = local.region.spoke_address_space
  nodes_subnet_prefix     = local.region.nodes_subnet_prefix
  endpoints_subnet_prefix = local.region.endpoints_subnet_prefix
  hub_vnet_id             = dependency.hub.outputs.vnet_id
  hub_vnet_name           = dependency.hub.outputs.vnet_name

  kubernetes_version              = local.env.kubernetes_version
  aks_sku_tier                    = local.env.aks_sku_tier
  private_cluster_enabled         = local.env.private_cluster_enabled
  api_server_authorized_ip_ranges = local.env.api_server_authorized_ip_ranges
  admin_group_object_ids          = local.env.admin_group_object_ids
  system_node_pool                = local.env.system_node_pool
  user_node_pools                 = local.env.user_node_pools
  network_policy                  = local.env.network_policy

  enable_acr                = local.env.enable_acr
  acr_sku                   = local.env.acr_sku
  enable_log_analytics      = local.env.enable_log_analytics
  log_retention_days        = local.env.log_retention_days
  enable_container_insights = local.env.enable_container_insights
  enable_defender           = local.env.enable_defender
  enable_azure_policy       = local.env.enable_azure_policy
  enable_telemetry          = local.env.enable_telemetry

  tags = {
    environment = local.env.environment
    managed_by  = "terragrunt"
    project     = "azure-aks-platform"
  }
}
