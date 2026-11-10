# Central private DNS: one zone per environment, svc.<env>.<base>, in the
# connectivity subscription. Stamps and hubs link their own VNets to it
# (from their own state, by zone ID - adding a stamp never touches this
# state) and each stamp's external-dns publishes its internal services into
# it, so stamp-to-stamp calls over the mesh use names, not IPs. Resolution
# inside Azure is Azure DNS via the links; on-prem needs the hub resolver
# (modules/hub enable_dns_resolver). Cost: ~$0.50/zone/month + queries.

resource "azurerm_resource_group" "dns" {
  count = length(local.dns_envs) > 0 ? 1 : 0

  name     = "rg-dns-platform"
  location = var.location
  tags     = var.tags
}

module "private_dns_zone" {
  for_each = local.dns_envs

  source = "git::https://github.com/Azure/terraform-azurerm-avm-res-network-privatednszone.git?ref=97ed94c12535fac61c3bad293754ba408b8a8d56" # v0.6.0

  domain_name      = "svc.${each.key}.${var.private_dns_base_domain}"
  parent_id        = azurerm_resource_group.dns[0].id
  enable_telemetry = var.enable_telemetry
  tags             = var.tags
}
