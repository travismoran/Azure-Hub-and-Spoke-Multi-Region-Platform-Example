locals {
  fw_mgmt_subnet_prefix = coalesce(var.firewall_management_subnet_prefix, cidrsubnet(var.address_space[0], 4, 1))
  fw_subnet_prefix      = coalesce(var.firewall_subnet_prefix, cidrsubnet(var.address_space[0], 4, 0))
  resource_group_name   = "rg-hub-${var.environment}-${var.region_short}"
  vnet_name             = "vnet-hub-${var.environment}-${var.region_short}"
}

resource "azurerm_resource_group" "hub" {
  location = var.location
  name     = local.resource_group_name
  tags     = var.tags
}

module "hub" {
  source  = "Azure/avm-ptn-hubnetworking/azurerm"
  version = "0.13.2"

  enable_telemetry = var.enable_telemetry
  tags             = var.tags

  hub_virtual_networks = {
    hub = {
      name                 = local.vnet_name
      address_space        = var.address_space
      location             = var.location
      parent_id            = azurerm_resource_group.hub.id
      mesh_peering_enabled = false

      # Firewall is the single most expensive resource in the whole platform.
      # null means the hub is a plain vnet that spokes peer into.
      firewall = var.enable_firewall ? {
        sku_name                         = "AZFW_VNet"
        sku_tier                         = var.firewall_sku_tier
        subnet_address_prefix            = local.fw_subnet_prefix
        management_ip_enabled            = true
        management_subnet_address_prefix = local.fw_mgmt_subnet_prefix
      } : null
    }
  }
}
