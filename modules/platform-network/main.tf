# Network platform for the whole tenant: ONE Azure Virtual Network Manager
# (AVNM) scoped to the top management group, a root IPAM pool per region
# split into environment pools that AKS stamp VNets allocate their /22 from,
# a tag-driven network group per environment, one global mesh per
# environment, and coarse security admin guardrails. Everything is gated by
# var.enabled so the unit always exists in the dependency graph but costs
# nothing when off.
#
# It deploys into the connectivity subscription (live/root.hcl placement)
# and manages VNets in every subscription under the management group. With
# management_group_id = null it scopes to its own subscription instead -
# the single-subscription mode. See docs/network-platform.md.

locals {
  n = var.enabled ? 1 : 0

  regions = var.enabled ? var.regions : {}
  envs    = var.enabled ? { for k, e in var.environments : k => e if e.enabled } : {}

  # env/region pairs that get a pool: "<env>/<region_short>".
  env_regions = merge([
    for env, e in local.envs : {
      for rs, r in e.regions : "${env}/${rs}" => merge(r, { env = env, region_short = rs })
    }
  ]...)

  # Per environment: its hubs (always-allow sources) and every OTHER
  # environment's stamp pools (deny sources), enabled or not.
  hub_prefixes = {
    for env, e in local.envs : env => distinct(flatten([for r in e.regions : r.hub_address_space]))
  }
  other_env_prefixes = {
    for env in keys(local.envs) : env => sort(distinct(flatten([
      for other, e in var.environments : [for r in e.regions : r.stamp_pool_prefix] if other != env
    ])))
  }

  scope_is_mg = var.management_group_id != null

  # Environments whose stamps get a default route to their regional hub
  # firewall pushed by AVNM (routing.tf).
  routing_envs = { for k, e in local.envs : k => e if e.routing && e.firewall }
  routing_env_regions = {
    for key, r in local.env_regions : key => r if contains(keys(local.routing_envs), r.env)
  }

  # Environments with a central private DNS zone (dns.tf). Independent of
  # var.enabled: the zone is useful without AVNM.
  dns_envs = { for k, e in var.environments : k => e if e.private_dns }
}

data "azurerm_subscription" "current" {}

resource "azurerm_resource_group" "avnm" {
  count = local.n

  name     = "rg-avnm-platform"
  location = var.location
  tags     = var.tags
}

resource "azurerm_network_manager" "this" {
  count = local.n

  name                = "avnm-platform"
  location            = var.location
  resource_group_name = azurerm_resource_group.avnm[0].name
  description         = "Network platform for the AKS stamps: IPAM, per-environment global mesh, security admin."
  scope_accesses      = concat(["Connectivity", "SecurityAdmin"], length(local.routing_envs) > 0 ? ["Routing"] : [])
  tags                = var.tags

  scope {
    management_group_ids = local.scope_is_mg ? [var.management_group_id] : null
    subscription_ids     = local.scope_is_mg ? null : [data.azurerm_subscription.current.id]
  }
}

# Root pool per region: the region's whole stamp address space, so the
# portal shows regional utilisation at a glance. Nothing allocates from a
# root directly.
resource "azurerm_network_manager_ipam_pool" "region" {
  for_each = local.regions

  name               = "ipam-${each.key}"
  location           = each.value.location
  network_manager_id = azurerm_network_manager.this[0].id
  display_name       = "aks-stamps-${each.value.location}"
  description        = "Root address pool for AKS stamp VNets in ${each.value.location}; split per environment."
  address_prefixes   = [each.value.root_pool_prefix]
  tags               = var.tags
}

# Environment pool per region, nested in the regional root. Stamps ask this
# pool for a prefix length, never a CIDR; IPAM guarantees no overlap. Pools
# cannot shrink once allocated from, so region.hcl sizes them generously (a
# /16 holds 64 stamps at /22).
resource "azurerm_network_manager_ipam_pool" "env" {
  for_each = local.env_regions

  name               = "ipam-${each.value.region_short}-${each.value.env}"
  location           = var.regions[each.value.region_short].location
  network_manager_id = azurerm_network_manager.this[0].id
  parent_pool_name   = azurerm_network_manager_ipam_pool.region[each.value.region_short].name
  display_name       = "aks-stamps-${each.value.env}-${var.regions[each.value.region_short].location}"
  description        = "Address pool for ${each.value.env} AKS stamp VNets in ${var.regions[each.value.region_short].location}."
  address_prefixes   = [each.value.stamp_pool_prefix]
  tags               = var.tags
}
