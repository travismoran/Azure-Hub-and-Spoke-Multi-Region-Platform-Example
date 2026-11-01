# Membership is dynamic: an Azure Policy in Microsoft.Network.Data mode adds
# every VNet tagged role=aks-stamp + env=<this env> to the group. A new stamp
# joins the mesh and inherits the security admin rules the moment its tagged
# VNet exists - no per-stamp AVNM work, and no dependency from this state on
# any stamp state (which would be circular: stamps depend on the pool IDs).
#
# Caveat (from the AVNM docs): these policies do not follow the normal policy
# evaluation cycle - membership updates on VNet create and tag change - and
# they survive deletion of the AVNM instance, which is why they live here and
# are removed in the same change.

resource "azurerm_network_manager_network_group" "stamps" {
  count = local.n

  name               = "ng-stamps-${var.environment}"
  network_manager_id = azurerm_network_manager.this[0].id
  description        = "AKS stamp VNets of ${var.environment} (dynamic membership by tags role=aks-stamp, env=${var.environment})."
}

resource "azurerm_policy_definition" "ng_stamps" {
  count = local.n

  name         = "avnm-ng-stamps-${var.environment}"
  policy_type  = "Custom"
  mode         = "Microsoft.Network.Data"
  display_name = "AVNM membership: AKS stamps (${var.environment})"
  description  = "Adds virtual networks tagged role=aks-stamp and env=${var.environment} to the ${var.environment} stamp network group."

  policy_rule = jsonencode({
    if = {
      allOf = [
        { field = "type", equals = "Microsoft.Network/virtualNetworks" },
        { field = "tags['role']", equals = "aks-stamp" },
        { field = "tags['env']", equals = var.environment },
      ]
    }
    then = {
      effect = "addToNetworkGroup"
      details = {
        networkGroupId = azurerm_network_manager_network_group.stamps[0].id
      }
    }
  })
}

resource "azurerm_subscription_policy_assignment" "ng_stamps" {
  count = local.n

  name                 = "avnm-ng-stamps-${var.environment}"
  display_name         = "AVNM membership: AKS stamps (${var.environment})"
  subscription_id      = data.azurerm_subscription.current.id
  policy_definition_id = azurerm_policy_definition.ng_stamps[0].id
}
