output "acr_login_server" {
  description = "Login server of the ACR, or null when ACR is disabled."
  value       = var.enable_acr ? "${local.acr_name}.azurecr.io" : null
}

output "cluster_id" {
  description = "Resource ID of the AKS cluster."
  value       = module.aks.resource_id
}

output "cluster_name" {
  description = "Name of the AKS cluster."
  value       = module.aks.name
}

output "kubelet_identity_object_id" {
  description = "Object ID of the kubelet managed identity (used for AcrPull grants)."
  value       = try(module.aks.kubelet_identity.objectId, null)
}

output "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics workspace, or null when disabled."
  value       = var.enable_log_analytics ? module.log_analytics[0].resource_id : null
}

output "node_resource_group" {
  description = "Name of the AKS-managed node resource group."
  value       = module.aks.node_resource_group_name
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL for workload identity federation."
  value       = module.aks.oidc_issuer_profile_issuer_url
}

output "node_subnet_prefixes" {
  description = "Prefixes of the node subnets. Unique per stamp, so other stamps can use them as the caller identity in Cilium/Kubernetes network policies."
  value       = [for k, s in local.subnets : module.subnet[k].address_prefixes[0] if s.nodes]
}

output "spoke_address_space" {
  description = "Prefix of the stamp VNet (static, or as allocated by AVNM IPAM)."
  value       = local.vnet_cidr
}

output "spoke_vnet_id" {
  description = "Resource ID of the spoke virtual network."
  value       = module.spoke_vnet.resource_id
}

output "spoke_vnet_name" {
  description = "Name of the spoke virtual network."
  value       = module.spoke_vnet.name
}

output "subnet_ids" {
  description = "Subnet resource IDs keyed by layout name (aks-system, aks-user, ilb, pe)."
  value       = { for k, s in module.subnet : k => s.resource_id }
}
