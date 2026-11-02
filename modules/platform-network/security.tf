# Security admin rules are evaluated before NSGs and cannot be overridden
# inside a stamp. They stay coarse on purpose (100 rules per level): a mesh
# opens layer 3 inside an environment, so who-may-call-whom is enforced
# in-cluster with network policies keyed on each stamp's unique node subnets
# (see the node_subnet_prefixes output of modules/aks-spoke).
#
# One configuration, one rule collection per environment (applied to that
# environment's network group):
#   100 allow-from-hubs                 the environment's hub ranges, every region
#   200 deny-inbound-from-other-envs    every other environment's stamp pools
#   300 deny-internet-high-risk-ports   Internet service tag on 22/3389/445/1433
# Priorities are unique across the WHOLE configuration (Azure rejects
# "Priority in Security Rule can't be overlapping" even across collections),
# so each environment adds a fixed offset: its index in the sorted list of
# all environments x 10 (dev 100/200/300, prod 110/210/310, ...). Indexing
# over all environments, not just enabled ones, keeps numbers stable when
# one is toggled.
#
# Not implemented on purpose: a "deny stamp-to-stamp on 22/10250" rule. With
# prefix-based sources it would also deny a cluster's own node-to-node
# kubelet traffic (metrics-server, Prometheus scrape pods SNAT to node IPs),
# since a rule cannot exclude "my own subnet". Do that per stamp with NSGs
# or Cilium instead.

locals {
  env_priority_offset = { for env in keys(var.environments) : env => 10 * index(sort(keys(var.environments)), env) }
}

resource "azurerm_network_manager_security_admin_configuration" "stamps" {
  count = local.n

  name               = "sac-stamps"
  network_manager_id = azurerm_network_manager.this[0].id
  description        = "Guardrails for AKS stamp VNets, one rule collection per environment."
}

resource "azurerm_network_manager_admin_rule_collection" "stamps" {
  for_each = local.envs

  name                            = "rc-stamps-${each.key}"
  security_admin_configuration_id = azurerm_network_manager_security_admin_configuration.stamps[0].id
  network_group_ids               = [azurerm_network_manager_network_group.stamps[each.key].id]
}

# 100: hub ranges (firewall, DNS resolver, monitoring) always reach stamps,
# whatever a stamp's NSGs say.
resource "azurerm_network_manager_admin_rule" "allow_from_hubs" {
  for_each = local.envs

  name                     = "allow-from-hubs"
  admin_rule_collection_id = azurerm_network_manager_admin_rule_collection.stamps[each.key].id
  description              = "Always allow inbound from the ${each.key} hub VNets of every region."
  action                   = "AlwaysAllow"
  direction                = "Inbound"
  priority                 = 100 + local.env_priority_offset[each.key]
  protocol                 = "Any"

  dynamic "source" {
    for_each = local.hub_prefixes[each.key]
    content {
      address_prefix_type = "IPPrefix"
      address_prefix      = source.value
    }
  }
}

# 200: backstop between environments. Separate meshes already leave them
# without a route to each other; this catches a misconfigured peering or
# on-prem route. Derived, not configured: every other environment's pools,
# whether or not that environment is in AVNM (static stamps use the same
# ranges).
resource "azurerm_network_manager_admin_rule" "deny_cross_env" {
  for_each = { for env in keys(local.envs) : env => env if length(local.other_env_prefixes[env]) > 0 }

  name                     = "deny-inbound-from-other-envs"
  admin_rule_collection_id = azurerm_network_manager_admin_rule_collection.stamps[each.key].id
  description              = "Deny inbound from other environments' stamp pools."
  action                   = "Deny"
  direction                = "Inbound"
  priority                 = 200 + local.env_priority_offset[each.key]
  protocol                 = "Any"

  dynamic "source" {
    for_each = local.other_env_prefixes[each.key]
    content {
      address_prefix_type = "IPPrefix"
      address_prefix      = source.value
    }
  }
}

# 300: nothing from the Internet on management/database ports, even if a
# stamp exposes a public load balancer on them by mistake.
resource "azurerm_network_manager_admin_rule" "deny_internet_high_risk_ports" {
  for_each = local.envs

  name                     = "deny-internet-high-risk-ports"
  admin_rule_collection_id = azurerm_network_manager_admin_rule_collection.stamps[each.key].id
  description              = "Deny inbound from Internet on ${join(",", var.high_risk_inbound_ports)}."
  action                   = "Deny"
  direction                = "Inbound"
  priority                 = 300 + local.env_priority_offset[each.key]
  protocol                 = "Tcp"
  destination_port_ranges  = var.high_risk_inbound_ports

  source {
    address_prefix_type = "ServiceTag"
    address_prefix      = "Internet"
  }
}

# Rule edits do not change the configuration ID, so the commit is re-triggered
# by a hash of the rule inputs.
resource "azurerm_network_manager_deployment" "security_admin" {
  for_each = local.regions

  network_manager_id = azurerm_network_manager.this[0].id
  location           = each.value.location
  scope_access       = "SecurityAdmin"
  configuration_ids  = [azurerm_network_manager_security_admin_configuration.stamps[0].id]

  triggers = {
    rules = sha256(jsonencode({
      envs  = sort(keys(local.envs))
      hubs  = local.hub_prefixes
      deny  = local.other_env_prefixes
      ports = var.high_risk_inbound_ports
    }))
  }

  depends_on = [
    azurerm_network_manager_admin_rule.allow_from_hubs,
    azurerm_network_manager_admin_rule.deny_cross_env,
    azurerm_network_manager_admin_rule.deny_internet_high_risk_ports,
  ]
}
