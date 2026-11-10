variable "name" {
  description = "Name of the user-assigned managed identity (convention id-<component>-<cluster>)."
  type        = string
}

variable "location" {
  description = "Region of the identity (the cluster's region)."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group of the identity (the cluster's stamp resource group)."
  type        = string
}

variable "oidc_issuer_url" {
  description = "The cluster's OIDC issuer URL (AKS oidc_issuer_profile.issuer_url)."
  type        = string
}

variable "service_account" {
  description = "namespace/name of the Kubernetes service account this identity is bound to (federated credential subject system:serviceaccount:<namespace>:<name>)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+/[a-z0-9-]+$", var.service_account))
    error_message = "service_account must be namespace/name."
  }
}

variable "role_assignments" {
  description = "Roles the identity holds, keyed by a stable name: { scope = <resource id>, role_definition_name = <built-in role>, description = optional }. Scope the narrowest resource that works (a zone, a vault, a container); never a subscription."
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
