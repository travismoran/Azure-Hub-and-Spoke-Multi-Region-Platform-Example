# Cross-stack contract consumed by aks-spoke via a terragrunt dependency
# block. Keep in sync with the mock_outputs in live/_envcommon/aks-spoke.hcl.
# Everything is null/empty when var.enabled is false.

output "network_manager_id" {
  description = "Resource ID of the AVNM instance, or null when disabled."
  value       = var.enabled ? azurerm_network_manager.this[0].id : null
}

output "network_group_ids" {
  description = "Resource ID of each environment's stamp network group, keyed by environment (empty when disabled)."
  value       = { for env, g in azurerm_network_manager_network_group.stamps : env => g.id }
}

output "ipam_pool_ids" {
  description = "IPAM pool resource IDs keyed by environment, then short region code (empty when disabled). A stamp allocates its VNet from its environment's pool in its region."
  value = {
    for env in keys(local.envs) : env => {
      for key, p in azurerm_network_manager_ipam_pool.env : local.env_regions[key].region_short => p.id
      if local.env_regions[key].env == env
    }
  }
}

output "ipam_pool_prefixes" {
  description = "Address prefix of each environment/region stamp pool keyed by environment, then short region code (empty when disabled)."
  value = {
    for env in keys(local.envs) : env => {
      for key, p in azurerm_network_manager_ipam_pool.env : local.env_regions[key].region_short => p.address_prefixes[0]
      if local.env_regions[key].env == env
    }
  }
}

output "root_pool_ids" {
  description = "Regional root IPAM pool resource IDs keyed by short region code (empty when disabled)."
  value       = { for rs, p in azurerm_network_manager_ipam_pool.region : rs => p.id }
}

output "private_dns_zone_ids" {
  description = "Resource ID of each environment's central private DNS zone (svc.<env>.<base>), keyed by environment; empty when no environment has private_dns."
  value       = { for env, z in module.private_dns_zone : env => z.resource_id }
}
