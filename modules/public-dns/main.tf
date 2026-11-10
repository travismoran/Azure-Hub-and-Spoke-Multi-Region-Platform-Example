# Public DNS hierarchy for this cloud (docs/dns.md):
#
#   example.com (registrar / outside this repo)
#   └── azure.example.com            parent zone, created here; delegate it
#       │                                ONCE at the registrar with the
#       │                                parent_name_servers output
#       ├── dev.azure.example.com    one child zone per environment,
#       └── prod.azure.example.com   NS-delegated from the parent here
#
# Applied once per tenant from live/platform (connectivity subscription) -
# every environment depends on it, so it is treated as production even when
# only dev exists. Cost: ~$0.50/zone/month + queries.

locals {
  n    = var.enabled ? 1 : 0
  envs = var.enabled ? toset(var.environments) : toset([])
}

resource "azurerm_resource_group" "dns" {
  count = local.n

  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

module "env_zone" {
  for_each = local.envs

  source = "git::https://github.com/Azure/terraform-azurerm-avm-res-network-dnszone.git?ref=5678e5b61e6ac24affc7c7aab03478edbe8c696e" # v0.2.1

  name                = "${each.key}.${var.parent_zone}"
  resource_group_name = azurerm_resource_group.dns[0].name
  enable_telemetry    = var.enable_telemetry
  tags                = var.tags
}

# The parent carries one NS record set per environment pointing at that
# child zone's Azure-assigned name servers, so a new environment is
# delegated the moment its zone exists.
module "parent_zone" {
  count = local.n

  source = "git::https://github.com/Azure/terraform-azurerm-avm-res-network-dnszone.git?ref=5678e5b61e6ac24affc7c7aab03478edbe8c696e" # v0.2.1

  name                = var.parent_zone
  resource_group_name = azurerm_resource_group.dns[0].name
  enable_telemetry    = var.enable_telemetry
  tags                = var.tags

  ns_records = {
    for env in local.envs : env => {
      name                = env
      resource_group_name = azurerm_resource_group.dns[0].name
      zone_name           = var.parent_zone
      ttl                 = var.delegation_ttl
      records             = tolist(module.env_zone[env].name_servers)
    }
  }
}
