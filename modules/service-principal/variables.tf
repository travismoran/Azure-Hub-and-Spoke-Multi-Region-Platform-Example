variable "display_name" {
  description = "Display name of the application and service principal (e.g. sp-eso-local)."
  type        = string
}

variable "description" {
  description = "What the principal is for; shown on the app registration and the service principal."
  type        = string
}

variable "owner_object_ids" {
  description = "Object IDs that own the application and service principal. Include the applying principal and any pipeline identity that must manage it with Application.ReadWrite.OwnedBy."
  type        = set(string)
}

variable "secret_rotation_days" {
  description = "Lifetime of the client secret in days; Terraform rotates it on the first apply after it elapses. 730 (24 months) is the Entra portal maximum."
  type        = number
  default     = 730

  validation {
    condition     = var.secret_rotation_days >= 1
    error_message = "secret_rotation_days must be at least 1."
  }
}

variable "secret_display_name" {
  description = "Display name of the client secret in the app registration."
  type        = string
  default     = "client secret"
}
