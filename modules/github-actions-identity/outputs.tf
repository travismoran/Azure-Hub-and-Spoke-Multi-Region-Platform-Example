output "client_id" {
  description = "Client ID: the repository's AZURE_CLIENT_ID variable for azure/login."
  value       = module.identity.client_id
}

output "principal_id" {
  description = "Object (principal) ID of the identity, for role assignments made elsewhere."
  value       = module.identity.principal_id
}

output "resource_id" {
  description = "Resource ID of the identity."
  value       = module.identity.resource_id
}

output "name" {
  description = "Name of the identity."
  value       = var.name
}

output "federated_subjects" {
  description = "Full OIDC subjects the identity trusts (prefix + suffix), for checking against a failed token exchange."
  value       = [for c in local.federated_credentials : c.subject]
}
