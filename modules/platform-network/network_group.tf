# One network group per environment. Membership is dynamic: an Azure Policy
# in Microsoft.Network.Data mode, assigned at the management group (so it
# covers every landing-zone subscription), adds every VNet tagged
# role=aks-stamp + env=<env> to that environment's group. A new stamp joins
# its mesh and inherits the security admin rules the moment its tagged VNet
# exists - no per-stamp AVNM work, and no dependency from this state on any
# stamp state (which would be circular: stamps depend on the pool IDs).
#
# Caveat (from the AVNM docs): these policies do not follow the normal policy
# evaluation cycle - membership updates on VNet create and tag change - and
# they survive deletion of the AVNM instance, which is why they live here and
# are removed in the same change.

resource "azurerm_network_manager_network_group" "stamps" {
  for_each = local.envs

  name               = "ng-stamps-${each.key}"
  network_manager_id = azurerm_network_manager.this[0].id
  description        = "AKS stamp VNets of ${each.key} (dynamic membership by tags role=aks-stamp, env=${each.key})."
}

resource "azurerm_policy_definition" "ng_stamps" {
  for_each = local.envs

  name                = "avnm-ng-stamps-${each.key}"
  policy_type         = "Custom"
  mode                = "Microsoft.Network.Data"
  display_name        = "AVNM membership: AKS stamps (${each.key})"
  description         = "Adds virtual networks tagged role=aks-stamp and env=${each.key} to the ${each.key} stamp network group."
  management_group_id = var.management_group_id

  policy_rule = jsonencode({
    if = {
      allOf = [
        { field = "type", equals = "Microsoft.Network/virtualNetworks" },
        { field = "tags['role']", equals = "aks-stamp" },
        { field = "tags['env']", equals = each.key },
      ]
    }
    then = {
      effect = "addToNetworkGroup"
      details = {
        networkGroupId = azurerm_network_manager_network_group.stamps[each.key].id
      }
    }
  })
}

# Assignment names at management-group scope are capped at 24 characters.
resource "azurerm_management_group_policy_assignment" "ng_stamps" {
  for_each = local.scope_is_mg ? local.envs : {}

  name                 = "avnm-ng-stamps-${each.key}"
  display_name         = "AVNM membership: AKS stamps (${each.key})"
  management_group_id  = var.management_group_id
  policy_definition_id = azurerm_policy_definition.ng_stamps[each.key].id
}

resource "azurerm_subscription_policy_assignment" "ng_stamps" {
  for_each = local.scope_is_mg ? {} : local.envs

  name                 = "avnm-ng-stamps-${each.key}"
  display_name         = "AVNM membership: AKS stamps (${each.key})"
  subscription_id      = data.azurerm_subscription.current.id
  policy_definition_id = azurerm_policy_definition.ng_stamps[each.key].id
}
