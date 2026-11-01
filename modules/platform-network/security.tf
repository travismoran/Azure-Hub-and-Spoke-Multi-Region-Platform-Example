# Security admin rules are evaluated before NSGs and cannot be overridden
# inside a stamp. They stay coarse on purpose (100 rules per level): a mesh
# opens layer 3 inside an environment, so who-may-call-whom is enforced
# in-cluster with network policies keyed on each stamp's unique node subnets
# (see the node_subnet_prefixes output of modules/aks-spoke).
#
# Not implemented on purpose: a "deny stamp-to-stamp on 22/10250" rule. With
# prefix-based sources it would also deny a cluster's own node-to-node
# kubelet traffic (metrics-server, Prometheus scrape pods SNAT to node IPs),
# since a rule cannot exclude "my own subnet". Do that per stamp with NSGs
# or Cilium instead.

resource "azurerm_network_manager_security_admin_configuration" "stamps" {
  count = local.n

  name               = "sac-stamps-${var.environment}"
  network_manager_id = azurerm_network_manager.this[0].id
  description        = "Guardrails for ${var.environment} AKS stamp VNets."
}

resource "azurerm_network_manager_admin_rule_collection" "stamps" {
  count = local.n

  name                            = "rc-stamps"
  security_admin_configuration_id = azurerm_network_manager_security_admin_configuration.stamps[0].id
  network_group_ids               = [azurerm_network_manager_network_group.stamps[0].id]
}

# 100: hub ranges (firewall, DNS resolver, monitoring) always reach stamps,
# whatever a stamp's NSGs say.
resource "azurerm_network_manager_admin_rule" "allow_from_hubs" {
  count = local.n

  name                     = "allow-from-hubs"
  admin_rule_collection_id = azurerm_network_manager_admin_rule_collection.stamps[0].id
  description              = "Always allow inbound from the hub VNets of every region."
  action                   = "AlwaysAllow"
  direction                = "Inbound"
  priority                 = 100
  protocol                 = "Any"

  dynamic "source" {
    for_each = local.hub_prefixes
    content {
      address_prefix_type = "IPPrefix"
      address_prefix      = source.value
    }
  }
}

# 200: backstop between environments. Separate meshes already leave prod and
# nonprod without a route to each other; this catches a misconfigured
# peering or on-prem route.
resource "azurerm_network_manager_admin_rule" "deny_cross_env" {
  count = var.enabled && length(var.security_admin_deny_inbound_from) > 0 ? 1 : 0

  name                     = "deny-inbound-from-other-envs"
  admin_rule_collection_id = azurerm_network_manager_admin_rule_collection.stamps[0].id
  description              = "Deny inbound from other environments' stamp pools."
  action                   = "Deny"
  direction                = "Inbound"
  priority                 = 200
  protocol                 = "Any"

  dynamic "source" {
    for_each = var.security_admin_deny_inbound_from
    content {
      address_prefix_type = "IPPrefix"
      address_prefix      = source.value
    }
  }
}

# 300: nothing from the Internet on management/database ports, even if a
# stamp exposes a public load balancer on them by mistake.
resource "azurerm_network_manager_admin_rule" "deny_internet_high_risk_ports" {
  count = local.n

  name                     = "deny-internet-high-risk-ports"
  admin_rule_collection_id = azurerm_network_manager_admin_rule_collection.stamps[0].id
  description              = "Deny inbound from Internet on ${join(",", var.high_risk_inbound_ports)}."
  action                   = "Deny"
  direction                = "Inbound"
  priority                 = 300
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
      hubs  = local.hub_prefixes
      deny  = var.security_admin_deny_inbound_from
      ports = var.high_risk_inbound_ports
    }))
  }

  depends_on = [
    azurerm_network_manager_admin_rule.allow_from_hubs,
    azurerm_network_manager_admin_rule.deny_cross_env,
    azurerm_network_manager_admin_rule.deny_internet_high_risk_ports,
  ]
}
