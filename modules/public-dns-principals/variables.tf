variable "enabled" {
  description = "Create the principals. When false nothing is created and every output is empty."
  type        = bool
  default     = true
}

variable "zone_ids" {
  description = "Public DNS zone resource ID per external environment (from the public-dns unit's env_zone_ids, filtered to platform.hcl external_environments). One service principal is created per key."
  type        = map(string)

  validation {
    condition     = alltrue([for id in values(var.zone_ids) : can(regex("(?i)^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft.Network/dnsZones/[^/]+$", id))])
    error_message = "Every zone_ids value must be a Microsoft.Network/dnszones resource ID."
  }
}

variable "name_prefix" {
  description = "Display-name prefix of the applications: <name_prefix>-<env>."
  type        = string
  default     = "sp-dns"
}

variable "secret_rotation_days" {
  description = "Lifetime of each client secret in days; Terraform rotates it on the first apply after it elapses. 730 (24 months) is the longest the Entra portal allows; the Graph API behind Terraform accepts more, and the tenant's app management policy may cap it."
  type        = number
  default     = 730

  validation {
    condition     = var.secret_rotation_days >= 1
    error_message = "secret_rotation_days must be at least 1."
  }
}

variable "owner_service_principal_names" {
  description = "Display names of service principals made owners of every application, in addition to the applying principal. Pipeline identities that hold only Application.ReadWrite.OwnedBy must be listed to manage the apps. Missing names are ignored."
  type        = list(string)
  default     = ["gh-cloud-platform-deploy"]
}
