# AVNM routing: for environments with enable_avnm_routing (and firewalls),
# push a 0.0.0.0/0 -> regional hub firewall route into every stamp's
# existing node route table (route_table_usage_mode = UseExisting), so new
# stamps egress through the firewall without a per-stamp route. Scaling
# alternative to the per-stamp default route modules/aks-spoke adds when
# outbound_type = userDefinedRouting (the spoke skips its own route when
# avnm_routing is on).
#
# The next hop differs per region, so routing needs per-env/region network
# groups (membership by tags + location) on top of the per-env groups the
# mesh uses. Firewall IPs are deterministic (ADR-005): first host of the
# first /26 of the hub range.

locals {
  firewall_ips = { for key, r in local.routing_env_regions : key => cidrhost(cidrsubnet(r.hub_address_space[0], 4, 0), 4) }
}

resource "azurerm_network_manager_network_group" "stamps_region" {
  for_each = local.routing_env_regions

  name               = "ng-stamps-${each.value.env}-${each.value.region_short}"
  network_manager_id = azurerm_network_manager.this[0].id
  description        = "AKS stamp VNets of ${each.value.env} in ${var.regions[each.value.region_short].location} (routing)."
}

resource "azurerm_policy_definition" "ng_stamps_region" {
  for_each = local.routing_env_regions

  name                = "avnm-ng-stamps-${each.value.env}-${each.value.region_short}"
  policy_type         = "Custom"
  mode                = "Microsoft.Network.Data"
  display_name        = "AVNM membership: AKS stamps (${each.value.env}, ${each.value.region_short})"
  description         = "Adds virtual networks tagged role=aks-stamp, env=${each.value.env} in ${var.regions[each.value.region_short].location} to the regional stamp network group."
  management_group_id = var.management_group_id

  policy_rule = jsonencode({
    if = {
      allOf = [
        { field = "type", equals = "Microsoft.Network/virtualNetworks" },
        { field = "location", equals = var.regions[each.value.region_short].location },
        { field = "tags['role']", equals = "aks-stamp" },
        { field = "tags['env']", equals = each.value.env },
      ]
    }
    then = {
      effect  = "addToNetworkGroup"
      details = { networkGroupId = azurerm_network_manager_network_group.stamps_region[each.key].id }
    }
  })
}

resource "azurerm_management_group_policy_assignment" "ng_stamps_region" {
  for_each = local.scope_is_mg ? local.routing_env_regions : {}

  name                 = substr("avnm-ng-${each.value.env}-${each.value.region_short}", 0, 24)
  display_name         = "AVNM membership: AKS stamps (${each.value.env}, ${each.value.region_short})"
  management_group_id  = var.management_group_id
  policy_definition_id = azurerm_policy_definition.ng_stamps_region[each.key].id
}

resource "azurerm_subscription_policy_assignment" "ng_stamps_region" {
  for_each = local.scope_is_mg ? {} : local.routing_env_regions

  name                 = substr("avnm-ng-${each.value.env}-${each.value.region_short}", 0, 24)
  display_name         = "AVNM membership: AKS stamps (${each.value.env}, ${each.value.region_short})"
  subscription_id      = data.azurerm_subscription.current.id
  policy_definition_id = azurerm_policy_definition.ng_stamps_region[each.key].id
}

resource "azurerm_network_manager_routing_configuration" "stamps" {
  for_each = local.routing_envs

  name                   = "rc-stamps-${each.key}"
  network_manager_id     = azurerm_network_manager.this[0].id
  description            = "Default route to the regional hub firewall for ${each.key} AKS stamps."
  route_table_usage_mode = "UseExisting"
}

resource "azurerm_network_manager_routing_rule_collection" "stamps_region" {
  for_each = local.routing_env_regions

  name                          = "rrc-stamps-${each.value.env}-${each.value.region_short}"
  routing_configuration_id      = azurerm_network_manager_routing_configuration.stamps[each.value.env].id
  network_group_ids             = [azurerm_network_manager_network_group.stamps_region[each.key].id]
  bgp_route_propagation_enabled = false
  description                   = "0.0.0.0/0 via the ${each.value.env} ${each.value.region_short} hub firewall."
}

resource "azurerm_network_manager_routing_rule" "default_via_firewall" {
  for_each = local.routing_env_regions

  name               = "default-via-firewall"
  rule_collection_id = azurerm_network_manager_routing_rule_collection.stamps_region[each.key].id
  description        = "Internet-bound traffic to the hub firewall (${local.firewall_ips[each.key]})."

  destination {
    type    = "AddressPrefix"
    address = "0.0.0.0/0"
  }

  next_hop {
    type    = "VirtualAppliance"
    address = local.firewall_ips[each.key]
  }
}

resource "azurerm_network_manager_deployment" "routing" {
  for_each = length(local.routing_envs) > 0 ? local.regions : {}

  network_manager_id = azurerm_network_manager.this[0].id
  location           = each.value.location
  scope_access       = "Routing"
  configuration_ids  = [for env in sort(keys(local.routing_envs)) : azurerm_network_manager_routing_configuration.stamps[env].id]

  triggers = {
    rules = sha256(jsonencode(local.firewall_ips))
  }

  depends_on = [
    azurerm_network_manager_routing_rule.default_via_firewall,
    azurerm_management_group_policy_assignment.ng_stamps_region,
    azurerm_subscription_policy_assignment.ng_stamps_region,
  ]
}
