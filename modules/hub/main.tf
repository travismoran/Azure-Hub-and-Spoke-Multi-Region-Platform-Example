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
      # Quirk: default_ip_configuration and both name attributes must be set
      # explicitly - the AVM module dereferences them without null guards
      # (optional object attrs exist as null, so its try() fallbacks no-op).
      firewall = var.enable_firewall ? {
        name                             = "fw-hub-${var.environment}-${var.region_short}"
        sku_name                         = "AZFW_VNet"
        sku_tier                         = var.firewall_sku_tier
        subnet_address_prefix            = local.fw_subnet_prefix
        management_ip_enabled            = true
        management_subnet_address_prefix = local.fw_mgmt_subnet_prefix
        default_ip_configuration = {
          name = "default"
          public_ip_config = {
            name = "pip-fw-hub-${var.environment}-${var.region_short}"
          }
        }
        # Policy SKU must match the firewall SKU.
        firewall_policy = {
          name = "fwp-hub-${var.environment}-${var.region_short}"
          sku  = var.firewall_sku_tier
        }
      } : null

      route_table_entries_firewall = var.enable_firewall ? [
        for r in var.firewall_route_entries : {
          name                = r.name
          address_prefix      = r.address_prefix
          next_hop_type       = "VirtualAppliance"
          next_hop_ip_address = r.next_hop_ip_address
        }
      ] : []
    }
  }
}

# The AVM-created policy ships with no rules (default deny). This collection
# lets private ranges transit the firewall - spoke->hub->hub->spoke.
resource "azurerm_firewall_policy_rule_collection_group" "transit" {
  count = var.enable_firewall ? 1 : 0

  name               = "rcg-private-transit"
  firewall_policy_id = module.hub.firewall_policies["hub"].id
  priority           = 200

  network_rule_collection {
    name     = "allow-private-transit"
    priority = 100
    action   = "Allow"

    rule {
      name                  = "private-to-private"
      protocols             = ["Any"]
      source_addresses      = var.transit_cidrs
      destination_addresses = var.transit_cidrs
      destination_ports     = ["*"]
    }
  }
}

# Global hub<->hub peering; both directions from one hub's state so only one
# side declares it. Transit traffic is forwarded by firewalls, hence
# allow_forwarded_traffic on both directions.
resource "azurerm_virtual_network_peering" "to_remote_hub" {
  count = var.peer_hub != null ? 1 : 0

  name                         = "peer-${local.vnet_name}-to-${var.peer_hub.vnet_name}"
  resource_group_name          = azurerm_resource_group.hub.name
  virtual_network_name         = module.hub.virtual_networks["hub"].name
  remote_virtual_network_id    = var.peer_hub.vnet_id
  allow_forwarded_traffic      = true
  allow_virtual_network_access = true
}

resource "azurerm_virtual_network_peering" "from_remote_hub" {
  count = var.peer_hub != null ? 1 : 0

  name                         = "peer-${var.peer_hub.vnet_name}-to-${local.vnet_name}"
  resource_group_name          = var.peer_hub.resource_group_name
  virtual_network_name         = var.peer_hub.vnet_name
  remote_virtual_network_id    = module.hub.virtual_networks["hub"].id
  allow_forwarded_traffic      = true
  allow_virtual_network_access = true
}
