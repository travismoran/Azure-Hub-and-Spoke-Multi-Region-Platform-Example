# Guardrail: every VNet that claims to be an AKS stamp must take its address
# space from one of the environment IPAM pools. A stamp applied with
# enable_avnm = false in an environment that is otherwise IPAM-allocated
# would overlap nothing today but is invisible to IPAM; Audit surfaces it,
# Deny stops it. Alias verified against Microsoft.Network on 2026-11-07:
# Microsoft.Network/virtualnetworks/addressSpace.ipamPoolPrefixAllocations[*].pool.id

resource "azurerm_policy_definition" "ipam_approved_pool" {
  count = var.enabled && var.enable_ipam_pool_policy ? 1 : 0

  name                = "aks-stamp-ipam-approved-pool"
  policy_type         = "Custom"
  mode                = "Indexed"
  display_name        = "AKS stamp VNets must allocate from an approved IPAM pool"
  description         = "Virtual networks tagged role=aks-stamp must have every address prefix allocated from one of the platform's environment IPAM pools."
  management_group_id = var.management_group_id

  parameters = jsonencode({
    approvedPoolIds = {
      type     = "Array"
      metadata = { displayName = "Approved IPAM pool resource IDs" }
    }
    effect = {
      type          = "String"
      allowedValues = ["Audit", "Deny", "Disabled"]
      defaultValue  = "Audit"
    }
  })

  policy_rule = jsonencode({
    if = {
      allOf = [
        { field = "type", equals = "Microsoft.Network/virtualNetworks" },
        { field = "tags['role']", equals = "aks-stamp" },
        {
          count = {
            field = "Microsoft.Network/virtualnetworks/addressSpace.ipamPoolPrefixAllocations[*]"
            where = {
              field = "Microsoft.Network/virtualnetworks/addressSpace.ipamPoolPrefixAllocations[*].pool.id"
              in    = "[parameters('approvedPoolIds')]"
            }
          }
          less = 1
        },
      ]
    }
    then = { effect = "[parameters('effect')]" }
  })
}

locals {
  ipam_policy_parameters = jsonencode({
    approvedPoolIds = { value = [for p in azurerm_network_manager_ipam_pool.env : p.id] }
    effect          = { value = var.ipam_pool_policy_effect }
  })
}

resource "azurerm_management_group_policy_assignment" "ipam_approved_pool" {
  count = var.enabled && var.enable_ipam_pool_policy && local.scope_is_mg ? 1 : 0

  name                 = "aks-stamp-ipam-pool"
  display_name         = "AKS stamp VNets must allocate from an approved IPAM pool"
  management_group_id  = var.management_group_id
  policy_definition_id = azurerm_policy_definition.ipam_approved_pool[0].id
  parameters           = local.ipam_policy_parameters
}

resource "azurerm_subscription_policy_assignment" "ipam_approved_pool" {
  count = var.enabled && var.enable_ipam_pool_policy && !local.scope_is_mg ? 1 : 0

  name                 = "aks-stamp-ipam-pool"
  display_name         = "AKS stamp VNets must allocate from an approved IPAM pool"
  subscription_id      = data.azurerm_subscription.current.id
  policy_definition_id = azurerm_policy_definition.ipam_approved_pool[0].id
  parameters           = local.ipam_policy_parameters
}
