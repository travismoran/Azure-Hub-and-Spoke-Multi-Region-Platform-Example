# One global mesh per environment: every stamp VNet in the group forms a
# single connected group across regions, so cluster-to-cluster traffic goes
# straight between spoke VNets on real node IPs - no hub hop, no NAT, no
# per-pair peerings. Hubs are deliberately NOT members: a hub must never
# become a transit path between environments. Hub<->spoke stays the plain
# peering the spoke module creates (egress firewall, DNS, on-prem).
#
# Direct connectivity is what makes unique address space mandatory - traffic
# to overlapping prefixes inside a connected group is dropped - which is why
# the stamp VNets are IPAM-allocated.
#
# Limits worth knowing (defaults; raised by request): 250 VNets and 128,000
# private addresses per connected group = 125 stamps at /22 per environment.

resource "azurerm_network_manager_connectivity_configuration" "mesh" {
  count = local.n

  name                  = "cc-mesh-${var.environment}"
  network_manager_id    = azurerm_network_manager.this[0].id
  description           = "Global mesh between all ${var.environment} AKS stamp VNets."
  connectivity_topology = "Mesh"
  global_mesh_enabled   = true

  applies_to_group {
    network_group_id    = azurerm_network_manager_network_group.stamps[0].id
    group_connectivity  = "None" # the Mesh topology itself connects the members
    global_mesh_enabled = true
  }
}

# AVNM configurations do nothing until committed per region. A global mesh is
# committed to every region that holds members; new members pick up the
# committed configuration automatically.
resource "azurerm_network_manager_deployment" "connectivity" {
  for_each = local.regions

  network_manager_id = azurerm_network_manager.this[0].id
  location           = each.value.location
  scope_access       = "Connectivity"
  configuration_ids  = [azurerm_network_manager_connectivity_configuration.mesh[0].id]

  depends_on = [azurerm_subscription_policy_assignment.ng_stamps]
}
