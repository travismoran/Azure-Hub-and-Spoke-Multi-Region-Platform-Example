variable "name" {
  description = "Key Vault name: 3-24 alphanumerics and dashes, globally unique (convention kv-<prefix>-<environment>)."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]{1,22}[a-zA-Z0-9]$", var.name))
    error_message = "Key Vault names are 3-24 characters, alphanumerics and dashes, starting with a letter."
  }
}

variable "location" {
  description = "Azure region of the vault (and resource group when created here)."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group of the vault; created here when create_resource_group is true, otherwise it must exist."
  type        = string
}

variable "create_resource_group" {
  description = "Create resource_group_name here (true for an environment vault; false when the caller owns the group, e.g. modules/local-cluster)."
  type        = bool
  default     = true
}

variable "officer_service_principal_names" {
  description = "Display names of service principals granted Key Vault Secrets Officer (pipeline identities that apply Terraform). The applying principal is always included. Missing names are ignored."
  type        = list(string)
  default     = ["gh-cloud-platform-deploy"]
}

variable "reader_service_principal_names" {
  description = "Display names of service principals granted Key Vault Secrets User (read): the plan pipeline identity, which must refresh the managed secrets' state. Missing names are ignored."
  type        = list(string)
  default     = ["gh-cloud-platform-plan"]
}

variable "additional_officer_principal_ids" {
  description = "Extra object IDs granted Key Vault Secrets Officer."
  type        = set(string)
  default     = []
}

variable "secrets_user_principals" {
  description = "Principals granted Key Vault Secrets User (read), keyed by a stable name: { principal_id, principal_type (ServicePrincipal/User/Group), description }. Consumers created after the vault (AKS workload identities) grant themselves instead."
  type = map(object({
    principal_id   = string
    principal_type = optional(string, "ServicePrincipal")
    description    = optional(string, null)
  }))
  default = {}
}

variable "managed_secrets" {
  description = "Secrets whose value Terraform owns, keyed by a stable key (the same key indexes managed_secret_values): { name, content_type, tags }."
  type = map(object({
    name         = string
    content_type = optional(string, "text/plain")
    tags         = optional(map(string), {})
  }))
  default = {}
}

variable "managed_secret_values" {
  description = "Values of managed_secrets, same keys. Sensitive."
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "generated_secrets" {
  description = "Secrets generated here with random_password (32 chars), keyed by a stable key: key => secret name."
  type        = map(string)
  default     = {}
}

variable "operator_managed_secret_names" {
  description = "Secrets created as placeholders (value REPLACE_ME) whose real value an operator sets once with `az keyvault secret set`; Terraform ignores later changes to them."
  type        = list(string)
  default     = []
}

variable "purge_protection_enabled" {
  description = "Key Vault purge protection. Off for development vaults so `destroy` can purge them; cannot be disabled once on."
  type        = bool
  default     = false
}

variable "soft_delete_retention_days" {
  description = "Key Vault soft-delete retention (7-90)."
  type        = number
  default     = 7
}

variable "enable_telemetry" {
  description = "Enable AVM module telemetry. Off by default: no phone-home from this platform."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
