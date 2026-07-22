locals {
  # ACR names: 5-50 chars, alphanumeric only, globally unique.
  acr_name            = "cr${var.name_prefix}${var.environment}${replace(var.region_short, "-", "")}"
  cluster_name        = "aks-${var.name_prefix}-${var.environment}-${var.region_short}"
  resource_group_name = "rg-aks-${var.environment}-${var.region_short}"
  vnet_name           = "vnet-aks-${var.environment}-${var.region_short}"
}

resource "azurerm_resource_group" "spoke" {
  location = var.location
  name     = local.resource_group_name
  tags     = var.tags
}

resource "azurerm_route_table" "nodes" {
  count = var.firewall_private_ip != null ? 1 : 0

  name                = "rt-aks-${var.environment}-${var.region_short}"
  location            = var.location
  resource_group_name = azurerm_resource_group.spoke.name
  tags                = var.tags
}

resource "azurerm_route" "via_firewall" {
  for_each = var.firewall_private_ip != null ? toset(var.firewall_routed_cidrs) : toset([])

  name                   = "to-${replace(replace(each.value, ".", "-"), "/", "--")}"
  resource_group_name    = azurerm_resource_group.spoke.name
  route_table_name       = azurerm_route_table.nodes[0].name
  address_prefix         = each.value
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = var.firewall_private_ip
}

module "spoke_vnet" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "0.19.0"

  name             = local.vnet_name
  parent_id        = azurerm_resource_group.spoke.id
  location         = var.location
  address_space    = var.spoke_address_space
  enable_telemetry = var.enable_telemetry
  tags             = var.tags

  subnets = {
    aks_nodes = {
      name             = "snet-aks-nodes"
      address_prefixes = [var.nodes_subnet_prefix]
      route_table      = var.firewall_private_ip != null ? { id = azurerm_route_table.nodes[0].id } : null
    }
    endpoints = {
      name             = "snet-endpoints"
      address_prefixes = [var.endpoints_subnet_prefix]
    }
  }

  # create_reverse_peering also creates the hub->spoke direction, so adding a
  # spoke never requires touching the hub's state.
  peerings = {
    hub = {
      name                               = "peer-${local.vnet_name}-to-${var.hub_vnet_name}"
      remote_virtual_network_resource_id = var.hub_vnet_id
      allow_forwarded_traffic            = true
      create_reverse_peering             = true
      reverse_name                       = "peer-${var.hub_vnet_name}-to-${local.vnet_name}"
      reverse_allow_forwarded_traffic    = true
      reverse_allow_gateway_transit      = true
    }
  }
}
