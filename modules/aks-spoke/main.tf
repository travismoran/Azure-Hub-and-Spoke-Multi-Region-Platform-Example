locals {
  # Every name carries the stamp suffix ("" for the first stamp of an
  # env/region, "-2", "-3", ... for additional ones) so N stamps can coexist.
  suffix = var.stamp_suffix
  # ACR names: 5-50 chars, alphanumeric only, globally unique.
  acr_name            = "cr${var.name_prefix}${var.environment}${replace(var.region_short, "-", "")}${replace(local.suffix, "-", "")}"
  cluster_name        = "aks-${var.name_prefix}-${var.environment}-${var.region_short}${local.suffix}"
  resource_group_name = "rg-aks-${var.environment}-${var.region_short}${local.suffix}"
  stamp_id            = "${var.name_prefix}-${var.environment}-${var.region_short}${local.suffix}"
  vnet_name           = "vnet-aks-${var.environment}-${var.region_short}${local.suffix}"

  use_ipam = var.ipam_pool_id != null

  # The VNet prefix is either the static one from region.hcl or whatever AVNM
  # IPAM allocated at apply time (then it is "known after apply" on the first
  # plan of a new stamp - expected).
  vnet_cidr = one(module.spoke_vnet.address_spaces) # set(string); one() also passes an unknown through

  # Fixed stamp layout, relative to the stamp prefix (shown for a /22; a /21
  # stamp doubles every subnet). Offsets not created here are reserved:
  #   .0.192/27 Private Link Service, .0.224/27 spare,
  #   .3.0/24 App Gateway for Containers / second user pool.
  # See docs/ipam.md.
  subnets = merge(
    {
      aks-system = { prefix = cidrsubnet(local.vnet_cidr, 3, 0), nodes = true, delegation = null }  # .0.0/25   system pool
      ilb        = { prefix = cidrsubnet(local.vnet_cidr, 5, 5), nodes = false, delegation = null } # .0.160/27 internal LB frontends other stamps call
      aks-user   = { prefix = cidrsubnet(local.vnet_cidr, 2, 1), nodes = true, delegation = null }  # .1.0/24   user pools
      pe         = { prefix = cidrsubnet(local.vnet_cidr, 2, 2), nodes = false, delegation = null } # .2.0/24   private endpoints
    },
    # .0.128/28: API server VNet integration (delegated to AKS). Created only
    # when the toggle is on; otherwise the offset stays reserved.
    var.enable_api_server_vnet_integration ? {
      apiserver = { prefix = cidrsubnet(local.vnet_cidr, 6, 8), nodes = false, delegation = "Microsoft.ContainerService/managedClusters" }
    } : {}
  )

  egress_via_firewall = var.outbound_type == "userDefinedRouting"

  # These four tags are the contract with the network platform: the AVNM
  # network group's membership policy matches on role + env.
  vnet_tags = merge(var.tags, {
    role       = "aks-stamp"
    env        = var.environment
    unit       = var.name_prefix
    "stamp-id" = local.stamp_id
  })
}

resource "azurerm_resource_group" "spoke" {
  location = var.location
  name     = local.resource_group_name
  tags     = var.tags
}

resource "azurerm_route_table" "nodes" {
  count = var.firewall_private_ip != null ? 1 : 0

  name                = "rt-aks-${var.environment}-${var.region_short}${local.suffix}"
  location            = var.location
  resource_group_name = azurerm_resource_group.spoke.name
  tags                = var.tags
}

# Never add routes for other stamps' prefixes when the AVNM mesh is on: a
# matching or more specific UDR overrides the connected-group route and
# silently pulls east-west traffic off the mesh. _envcommon passes an empty
# list in that case.
resource "azurerm_route" "via_firewall" {
  for_each = var.firewall_private_ip != null ? toset(var.firewall_routed_cidrs) : toset([])

  name                   = "to-${replace(replace(each.value, ".", "-"), "/", "--")}"
  resource_group_name    = azurerm_resource_group.spoke.name
  route_table_name       = azurerm_route_table.nodes[0].name
  address_prefix         = each.value
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = var.firewall_private_ip
}

# outbound_type = userDefinedRouting: all internet-bound traffic from the
# nodes goes to the hub firewall (which must carry the AKS egress rules -
# modules/hub aks_egress_via_firewall). Not added when AVNM routing pushes
# the same default route (avnm_routing), so the two never fight.
resource "azurerm_route" "default_via_firewall" {
  count = local.egress_via_firewall && !var.avnm_routing ? 1 : 0

  name                   = "default-via-firewall"
  resource_group_name    = azurerm_resource_group.spoke.name
  route_table_name       = azurerm_route_table.nodes[0].name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = var.firewall_private_ip
}

# A VNet uses either IPAM pools or a static address_space, never both
# (CannotMixAddressPrefixAndPoolInPayload). Subnets are created separately
# below because their prefixes derive from this module's output.
module "spoke_vnet" {
  source = "git::https://github.com/Azure/terraform-azurerm-avm-res-network-virtualnetwork.git?ref=7700fb912c3e735b2806faee01e7682af425c46d" # v0.19.0

  name             = local.vnet_name
  parent_id        = azurerm_resource_group.spoke.id
  location         = var.location
  enable_telemetry = var.enable_telemetry
  tags             = local.vnet_tags

  address_space = local.use_ipam ? null : var.spoke_address_space
  ipam_pools = local.use_ipam ? [{
    id            = var.ipam_pool_id
    prefix_length = var.stamp_prefix_length
  }] : null

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

# Static subnets inside an IPAM-allocated VNet is a supported mix (AVM
# virtualnetwork subnet module README: "IPAM VNet + Traditional Subnet").
module "subnet" {
  source = "git::https://github.com/Azure/terraform-azurerm-avm-res-network-virtualnetwork.git//modules/subnet?ref=7700fb912c3e735b2806faee01e7682af425c46d" # v0.19.0

  for_each = local.subnets

  name                            = "snet-${each.key}"
  parent_id                       = module.spoke_vnet.resource_id
  address_prefixes                = [each.value.prefix]
  default_outbound_access_enabled = false
  route_table                     = each.value.nodes && var.firewall_private_ip != null ? { id = azurerm_route_table.nodes[0].id } : null
  delegations = each.value.delegation == null ? null : [{
    name               = "aks"
    service_delegation = { name = each.value.delegation }
  }]
}

# Link the stamp VNet to its environment's central private DNS zone
# (modules/platform-network, enable_private_dns) so pods resolve
# svc.<env>.platform.internal through Azure DNS - no resolver needed inside
# Azure. azapi because the zone lives in the connectivity subscription and
# the azurerm link resource cannot cross subscriptions.
resource "azapi_resource" "private_dns_link" {
  count = var.private_dns_zone_id != null ? 1 : 0

  type      = "Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01"
  name      = local.vnet_name
  parent_id = var.private_dns_zone_id
  location  = "global"
  tags      = var.tags

  body = {
    properties = {
      virtualNetwork      = { id = module.spoke_vnet.resource_id }
      registrationEnabled = false
    }
  }
}
