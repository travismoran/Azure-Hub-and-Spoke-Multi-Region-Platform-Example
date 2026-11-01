# Cross-stack contract consumed by aks-spoke via a terragrunt dependency
# block. Keep in sync with the mock_outputs in live/_envcommon/aks-spoke.hcl.
# Everything is null/empty when var.enabled is false.

output "network_manager_id" {
  description = "Resource ID of the AVNM instance, or null when disabled."
  value       = var.enabled ? azurerm_network_manager.this[0].id : null
}

output "network_group_id" {
  description = "Resource ID of the stamp network group, or null when disabled."
  value       = var.enabled ? azurerm_network_manager_network_group.stamps[0].id : null
}

output "ipam_pool_ids" {
  description = "IPAM pool resource IDs keyed by short region code (empty when disabled). A stamp allocates its VNet from its region's pool."
  value       = { for k, p in azurerm_network_manager_ipam_pool.stamps : k => p.id }
}

output "ipam_pool_prefixes" {
  description = "Address prefix of each regional stamp pool keyed by short region code (empty when disabled)."
  value       = { for k, p in azurerm_network_manager_ipam_pool.stamps : k => p.address_prefixes[0] }
}
