# Network platform for one environment: an Azure Virtual Network Manager
# (AVNM) instance scoped to the subscription, one IPAM pool per region that
# AKS stamp VNets allocate their /22 from, a tag-driven network group, a
# global mesh connecting every stamp of the environment, and coarse security
# admin guardrails. Everything is gated by var.enabled (count/for_each) so the
# unit always exists in the dependency graph but costs nothing when off.
#
# Enterprise target vs. this example: the design this is adapted from runs
# ONE AVNM at the top management group with region-root -> environment pool
# hierarchies. This repo has one subscription and independent env trees, so
# it runs one AVNM per environment at subscription scope - same resources,
# same tag contract, narrower scope. See docs/network-platform.md.

locals {
  n       = var.enabled ? 1 : 0
  regions = var.enabled ? var.regions : {}

  hub_prefixes   = distinct(flatten([for r in var.regions : r.hub_address_space]))
  stamp_prefixes = [for r in var.regions : r.stamp_pool_prefix]
}

data "azurerm_subscription" "current" {}

resource "azurerm_resource_group" "avnm" {
  count = local.n

  name     = "rg-avnm-${var.environment}"
  location = var.location
  tags     = var.tags
}

resource "azurerm_network_manager" "this" {
  count = local.n

  name                = "avnm-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.avnm[0].name
  description         = "Network platform for the ${var.environment} AKS stamps: IPAM, global mesh, security admin."
  scope_accesses      = ["Connectivity", "SecurityAdmin"]
  tags                = var.tags

  scope {
    subscription_ids = [data.azurerm_subscription.current.id]
  }
}

# One pool per region. Stamps ask for a prefix length, never a CIDR; IPAM
# guarantees no overlap inside the pool. Pools cannot shrink once allocated
# from, so region.hcl sizes them generously (a /16 holds 64 stamps at /22).
resource "azurerm_network_manager_ipam_pool" "stamps" {
  for_each = local.regions

  name               = "ipam-stamps-${var.environment}-${each.key}"
  location           = each.value.location
  network_manager_id = azurerm_network_manager.this[0].id
  display_name       = "AKS stamps ${var.environment} ${each.value.location}"
  description        = "Address pool for AKS stamp VNets in ${each.value.location} (${var.environment})."
  address_prefixes   = [each.value.stamp_pool_prefix]
  tags               = var.tags
}
