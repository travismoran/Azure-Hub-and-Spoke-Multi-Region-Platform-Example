# Consumed by <gitops-repo>/scripts/bootstrap-external-secrets.sh
# (`terragrunt output -json`): the one secret loaded into the cluster by hand.

output "resource_group_name" {
  description = "Resource group holding the environment's Azure resources."
  value       = azurerm_resource_group.this.name
}

output "key_vault_name" {
  description = "Key Vault name."
  value       = module.vault.name
}

output "key_vault_uri" {
  description = "Key Vault URI (ClusterSecretStore spec.provider.azurekv.vaultUrl)."
  value       = module.vault.uri
}

output "key_vault_id" {
  description = "Key Vault resource ID."
  value       = module.vault.resource_id
}

output "tenant_id" {
  description = "Tenant (ClusterSecretStore spec.provider.azurekv.tenantId)."
  value       = data.azuread_client_config.current.tenant_id
}

output "eso_client_id" {
  description = "Client ID of sp-eso-<env> (ClusterSecretStore authSecretRef.clientId)."
  value       = module.eso_principal.client_id
}

output "eso_object_id" {
  description = "Object ID of sp-eso-<env>."
  value       = module.eso_principal.object_id
}

output "eso_client_secret" {
  description = "Client secret of sp-eso-<env>. SECRET: goes into the cluster secret external-secrets/azure-kv-sp and nowhere else."
  value       = module.eso_principal.client_secret
  sensitive   = true
}

output "eso_secret_end_date" {
  description = "Expiry of the ESO client secret; Terraform rotates it on the first apply after this date."
  value       = module.eso_principal.secret_end_date
}

output "managed_secret_names" {
  description = "Key Vault secret names Terraform maintains in this vault."
  value       = module.vault.managed_secret_names
}

output "operator_secret_names" {
  description = "Key Vault secrets created as placeholders whose real value an operator must set by hand (`az keyvault secret set`)."
  value       = module.vault.operator_secret_names
}

# --- Container registry (acr.tf) ----------------------------------------------

output "acr_login_server" {
  description = "Registry login server (image prefix, the source repositories' ACR_LOGIN_SERVER variable); null when enable_acr is false."
  value       = try(azurerm_container_registry.this[0].login_server, null)
}

output "acr_id" {
  description = "Registry resource ID; null when enable_acr is false."
  value       = try(azurerm_container_registry.this[0].id, null)
}

output "acr_push_client_ids" {
  description = "Client ID of the push identity per acr_push_repositories key: that repository's AZURE_CLIENT_ID variable for azure/login."
  value       = { for k, m in module.push_identity : k => m.client_id }
}

output "acr_push_subjects" {
  description = "Federated OIDC subjects each push identity trusts, per acr_push_repositories key."
  value       = { for k, m in module.push_identity : k => m.federated_subjects }
}

output "acr_pull_token_name" {
  description = "Name of the repository-scoped pull token (the imagePullSecret username; its password is the vault secret acr-pull-password)."
  value       = try(azurerm_container_registry_token.pull[0].name, null)
}

output "acr_pull_password_end_date" {
  description = "Expiry of the pull token password; Terraform rotates it on the first apply after this date."
  value       = try(time_rotating.acr_pull[0].rotation_rfc3339, null)
}
