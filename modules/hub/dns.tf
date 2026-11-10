# Hub side of the central private DNS zone (modules/platform-network,
# enable_private_dns): link the hub VNet to the zone, and optionally run a
# DNS Private Resolver inbound endpoint so clients outside Azure (VPN,
# ExpressRoute) can resolve it by forwarding to a hub IP.

resource "azapi_resource" "private_dns_link" {
  count = var.private_dns_zone_id != null ? 1 : 0

  type      = "Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01"
  name      = local.vnet_name
  parent_id = var.private_dns_zone_id
  location  = "global"
  tags      = var.tags

  body = {
    properties = {
      virtualNetwork      = { id = module.hub.virtual_networks["hub"].id }
      registrationEnabled = false
    }
  }
}

module "dns_resolver" {
  count = var.enable_dns_resolver ? 1 : 0

  source = "git::https://github.com/Azure/terraform-azurerm-avm-res-network-dnsresolver.git?ref=73b1df385505485dee12fc3901756d4994fe9cc8" # v0.8.0

  name                        = "dnspr-hub-${var.environment}-${var.region_short}"
  location                    = var.location
  resource_group_name         = azurerm_resource_group.hub.name
  virtual_network_resource_id = module.hub.virtual_networks["hub"].id
  enable_telemetry            = var.enable_telemetry
  tags                        = var.tags

  inbound_endpoints = {
    hub = {
      name        = "in-hub-${var.environment}-${var.region_short}"
      subnet_name = "snet-dns-inbound"
    }
  }
}
