# Consumed by <gitops-repo>/scripts/azure-dns-local-credentials.sh
# (`terragrunt output -json`), which turns these into the two cluster secrets
# external-dns/azure-config-file and cert-manager/azuredns-sp. All maps are
# keyed by environment. Only client_secrets and azure_json are secret.

output "client_ids" {
  description = "Application (client) ID of each environment's service principal - goes into the ClusterIssuer (clientID) and azure.json (aadClientId)."
  value       = { for env in local.envs : env => module.principal[env].client_id }
}

output "object_ids" {
  description = "Object ID of each service principal (role assignment principal)."
  value       = { for env in local.envs : env => module.principal[env].object_id }
}

output "tenant_id" {
  description = "Tenant the principals live in."
  value       = data.azuread_client_config.current.tenant_id
}

output "zone_names" {
  description = "Zone each principal may write, keyed by environment."
  value       = { for env in local.envs : env => local.zone_name[env] }
}

output "zone_subscription_ids" {
  description = "Subscription holding each environment's zone (ClusterIssuer subscriptionID, azure.json subscriptionId)."
  value       = { for env in local.envs : env => local.subscription_id[env] }
}

output "zone_resource_groups" {
  description = "Resource group holding each environment's zone (ClusterIssuer resourceGroupName, azure.json resourceGroup)."
  value       = { for env in local.envs : env => local.resource_group[env] }
}

output "secret_end_dates" {
  description = "Expiry of each client secret (RFC 3339); Terraform rotates it on the first apply after this date."
  value       = { for env in local.envs : env => module.principal[env].secret_end_date }
}

output "client_secrets" {
  description = "Client secret per environment. SECRET: read with `terragrunt output -raw`/-json into the cluster, never into a file in any repo."
  value       = { for env in local.envs : env => module.principal[env].client_secret }
  sensitive   = true
}

output "azure_json" {
  description = "Ready-made external-dns Azure provider config (azure.json) per environment. SECRET: contains aadClientSecret."
  value = {
    for env in local.envs : env => jsonencode({
      tenantId        = data.azuread_client_config.current.tenant_id
      subscriptionId  = local.subscription_id[env]
      resourceGroup   = local.resource_group[env]
      aadClientId     = module.principal[env].client_id
      aadClientSecret = module.principal[env].client_secret
    })
  }
  sensitive = true
}
