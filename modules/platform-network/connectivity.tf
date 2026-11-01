# One global mesh per environment: every stamp VNet in the environment's
# group forms a single connected group across regions and subscriptions, so
# cluster-to-cluster traffic goes straight between spoke VNets on real node
# IPs - no hub hop, no NAT, no per-pair peerings. Environments never share a
# mesh, and hubs are deliberately NOT members: a hub must never become a
# transit path between environments. Hub<->spoke stays the plain peering the
# spoke module creates (egress firewall, DNS, on-prem).
#
# Direct connectivity is what makes unique address space mandatory - traffic
# to overlapping prefixes inside a connected group is dropped - which is why
# the stamp VNets are IPAM-allocated.
#
# Limits worth knowing (defaults; raised by request): 250 VNets and 128,000
# private addresses per connected group = 125 stamps at /22 per environment.

resource "azurerm_network_manager_connectivity_configuration" "mesh" {
  for_each = local.envs

  name                  = "cc-mesh-${each.key}"
  network_manager_id    = azurerm_network_manager.this[0].id
  description           = "Global mesh between all ${each.key} AKS stamp VNets."
  connectivity_topology = "Mesh"
  global_mesh_enabled   = true

  applies_to_group {
    network_group_id    = azurerm_network_manager_network_group.stamps[each.key].id
    group_connectivity  = "None" # the Mesh topology itself connects the members
    global_mesh_enabled = true
  }
}

# AVNM configurations do nothing until committed per region, and a commit
# replaces the whole set of configurations for that region and scope - so
# every environment's mesh is listed in each region's single commit. New
# members pick up the committed configuration automatically.
resource "azurerm_network_manager_deployment" "connectivity" {
  for_each = local.regions

  network_manager_id = azurerm_network_manager.this[0].id
  location           = each.value.location
  scope_access       = "Connectivity"
  configuration_ids  = [for env in sort(keys(local.envs)) : azurerm_network_manager_connectivity_configuration.mesh[env].id]

  depends_on = [
    azurerm_management_group_policy_assignment.ng_stamps,
    azurerm_subscription_policy_assignment.ng_stamps,
  ]
}
