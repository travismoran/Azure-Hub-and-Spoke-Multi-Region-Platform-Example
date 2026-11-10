# Cross-stack contract consumed by aks-spoke via a terragrunt dependency
# block. Keep in sync with the mock_outputs in live/_envcommon/aks-spoke.hcl.
# Everything is null/empty when var.enabled is false.

output "parent_zone_name" {
  description = "Name of the parent public zone (e.g. azure.example.com), or null when disabled."
  value       = var.enabled ? var.parent_zone : null
}

output "parent_zone_id" {
  description = "Resource ID of the parent public zone, or null when disabled."
  value       = var.enabled ? module.parent_zone[0].resource_id : null
}

output "parent_name_servers" {
  description = "Azure DNS name servers of the parent zone - the NS records to create ONCE at the registrar for the parent_zone label (empty when disabled)."
  value       = var.enabled ? tolist(module.parent_zone[0].name_servers) : []
}

output "env_zone_ids" {
  description = "Resource ID of each environment's public zone (<env>.<parent_zone>), keyed by environment."
  value       = { for env, z in module.env_zone : env => z.resource_id }
}

output "env_zone_names" {
  description = "Name of each environment's public zone, keyed by environment."
  value       = { for env in local.envs : env => "${env}.${var.parent_zone}" }
}

output "resource_group_name" {
  description = "Resource group holding the zones (grant Reader here for external-dns), or null when disabled."
  value       = var.enabled ? azurerm_resource_group.dns[0].name : null
}
