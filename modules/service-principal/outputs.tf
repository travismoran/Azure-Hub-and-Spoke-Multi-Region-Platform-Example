output "client_id" {
  description = "Application (client) ID."
  value       = azuread_application.this.client_id
}

output "object_id" {
  description = "Object ID of the service principal (use as role assignment principal_id)."
  value       = azuread_service_principal.this.object_id
}

output "application_object_id" {
  description = "Object ID of the application registration."
  value       = azuread_application.this.object_id
}

output "client_secret" {
  description = "The client secret. SECRET: never write it to a file in any repo."
  value       = azuread_application_password.this.value
  sensitive   = true
}

output "secret_end_date" {
  description = "Expiry of the client secret (RFC 3339)."
  value       = azuread_application_password.this.end_date
}
