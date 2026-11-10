variable "name" {
  description = "Name of the user-assigned managed identity (convention id-gh-<repo>-<environment>)."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9-_]{2,127}$", var.name))
    error_message = "name must be 3-128 characters of alphanumerics, dashes or underscores, starting alphanumeric."
  }
}

variable "location" {
  description = "Azure region of the identity."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group of the identity (the environment's resource group)."
  type        = string
}

variable "repository" {
  description = "GitHub repository the identity is for, as owner/name (e.g. your-org/app-a). Used for the default subject prefix repo:<owner>/<name>."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.repository))
    error_message = "repository must be owner/name."
  }
}

variable "subject_prefix" {
  description = "GitHub OIDC subject prefix for the repository (`gh api repos/<owner>/<name>/actions/oidc/customization/sub`, field sub_claim_prefix). Required when the repository uses immutable subjects (repo:<owner>@<id>/<name>@<id>); null or empty = repo:<repository>."
  type        = string
  default     = null
}

variable "subjects" {
  description = "Subject suffixes that may assume the identity, e.g. ref:refs/heads/main, ref:refs/tags/v1.2.3, environment:prod, pull_request. One federated credential each (identity limit 20)."
  type        = list(string)
  default     = ["ref:refs/heads/main"]

  validation {
    condition     = length(var.subjects) >= 1 && length(var.subjects) <= 20
    error_message = "subjects must hold 1-20 entries (a managed identity holds at most 20 federated credentials)."
  }
}

variable "role_assignments" {
  description = "Roles the identity holds, keyed by a stable name: { scope = <resource id>, role_definition_name = <built-in role>, description = optional }. Scope the narrowest resource that works (one registry, one storage container); never a subscription."
  type = map(object({
    scope                = string
    role_definition_name = string
    description          = optional(string, null)
  }))
  default = {}
}

variable "enable_telemetry" {
  description = "Enable AVM module telemetry. Off by default: no phone-home from this platform."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to the identity."
  type        = map(string)
  default     = {}
}
