# Minimal landing-zone shaped hierarchy. Management groups are free and
# tenant-scoped; the one-time prerequisite is tenant-root access for the
# deploying identity (docs/subscriptions.md).
#
#   Tenant Root Group
#   └── mg-<prefix>                 <- AVNM scope, network-group policies
#       ├── mg-<prefix>-platform    <- management (state) + connectivity (hubs, AVNM)
#       └── mg-<prefix>-landingzones
#           └── mg-<prefix>-<env>   <- that environment's subscription (AKS stamps)

locals {
  n = var.enabled ? 1 : 0

  platform_roles = ["connectivity", "management"]

  # id => [roles...]; the first role (lexical) decides placement.
  subscription_roles = {
    for role, id in var.subscriptions : id => role...
    if id != ""
  }
  placement = { for id, roles in local.subscription_roles : id => sort(roles)[0] }

  platform_subscriptions = [for id, role in local.placement : id if contains(local.platform_roles, role)]
  env_subscriptions = {
    for env in var.environments : env => [for id, role in local.placement : id if role == env]
  }
}

resource "azurerm_management_group" "top" {
  count = local.n

  name         = "mg-${var.name_prefix}"
  display_name = var.name_prefix
}

resource "azurerm_management_group" "platform" {
  count = local.n

  name                       = "mg-${var.name_prefix}-platform"
  display_name               = "${var.name_prefix} platform"
  parent_management_group_id = azurerm_management_group.top[0].id
  subscription_ids           = local.platform_subscriptions
}

resource "azurerm_management_group" "landing_zones" {
  count = local.n

  name                       = "mg-${var.name_prefix}-landingzones"
  display_name               = "${var.name_prefix} landing zones"
  parent_management_group_id = azurerm_management_group.top[0].id
}

resource "azurerm_management_group" "env" {
  for_each = var.enabled ? toset(var.environments) : toset([])

  name                       = "mg-${var.name_prefix}-${each.key}"
  display_name               = "${var.name_prefix} ${each.key}"
  parent_management_group_id = azurerm_management_group.landing_zones[0].id
  subscription_ids           = local.env_subscriptions[each.key]
}

# AVNM at management-group scope requires the Microsoft.Network provider to
# be registered on that management group (there is no azurerm resource for
# this; it is a POST on the management group). Runs once at create.
resource "azapi_resource_action" "register_network" {
  count = var.enabled && var.register_network_provider ? 1 : 0

  type        = "Microsoft.Management/managementGroups@2021-04-01"
  resource_id = azurerm_management_group.top[0].id
  action      = "providers/Microsoft.Network/register"
  method      = "POST"
}
