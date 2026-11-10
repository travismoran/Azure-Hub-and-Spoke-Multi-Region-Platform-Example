# Cross-stack contract consumed by aks-spoke via a terragrunt dependency
# block. Keep in sync with the keyvault mock_outputs in live/_envcommon/aks-spoke.hcl.

output "name" {
  description = "Key Vault name."
  value       = module.key_vault.name
}

output "uri" {
  description = "Key Vault URI (ClusterSecretStore spec.provider.azurekv.vaultUrl)."
  value       = module.key_vault.uri
}

output "resource_id" {
  description = "Key Vault resource ID (scope for Key Vault Secrets User grants)."
  value       = module.key_vault.resource_id
}

output "resource_group_name" {
  description = "Resource group holding the vault."
  value       = local.resource_group_name
}

output "tenant_id" {
  description = "Tenant of the vault (ClusterSecretStore spec.provider.azurekv.tenantId)."
  value       = data.azuread_client_config.current.tenant_id
}

output "managed_secret_names" {
  description = "Secret names Terraform maintains the value of (managed + generated)."
  value       = [for s in local.secrets : s.name]
}

output "operator_secret_names" {
  description = "Placeholder secrets whose real value an operator must set by hand."
  value       = [for s in azurerm_key_vault_secret.operator_managed : s.name]
}
