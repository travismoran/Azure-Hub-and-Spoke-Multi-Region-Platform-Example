# Cross-stack contract consumed by live/platform/network via a terragrunt
# dependency block. Keep in sync with the mock_outputs in
# live/_envcommon/platform-network.hcl. Null/empty when var.enabled is false.

output "top_management_group_id" {
  description = "Resource ID of the top management group (the AVNM and policy scope), or null when disabled."
  value       = var.enabled ? azurerm_management_group.top[0].id : null
}

output "management_group_ids" {
  description = "Resource IDs of every management group by key: top, platform, landing_zones, and one per environment."
  value = var.enabled ? merge(
    {
      top           = azurerm_management_group.top[0].id
      platform      = azurerm_management_group.platform[0].id
      landing_zones = azurerm_management_group.landing_zones[0].id
    },
    { for env, mg in azurerm_management_group.env : env => mg.id },
  ) : {}
}

output "subscription_placement" {
  description = "Which management group role each known subscription ID was placed under."
  value       = var.enabled ? local.placement : {}
}
