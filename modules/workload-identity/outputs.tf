output "client_id" {
  description = "Client ID: the azure.workload.identity/client-id annotation on the service account."
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
