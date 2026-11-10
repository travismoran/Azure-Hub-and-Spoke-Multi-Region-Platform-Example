variable "enabled" {
  description = "Create the public DNS hierarchy. When false nothing is created and every output is null/empty (stamps then get no public zone to publish into)."
  type        = bool
  default     = true
}

variable "parent_zone" {
  description = "Public DNS zone for this cloud, delegated from the organisation's apex at the registrar (e.g. azure.example.com; another cloud could use aws.example.com the same way). Every environment gets <env>.<parent_zone> delegated from it here."
  type        = string

  validation {
    condition     = can(regex("^([a-z0-9-]+\\.)+[a-z]{2,}$", var.parent_zone))
    error_message = "parent_zone must be a lowercase DNS name such as azure.example.com."
  }
}

variable "environments" {
  description = "Environment names; each gets a child zone <env>.<parent_zone> and an NS delegation record in the parent."
  type        = list(string)

  validation {
    condition     = alltrue([for e in var.environments : can(regex("^[a-z0-9-]{1,20}$", e))])
    error_message = "Environment names must be 1-20 lowercase alphanumerics or dashes (they become DNS labels)."
  }
}

variable "location" {
  description = "Region of the resource group (DNS zones themselves are global)."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group holding the parent and environment zones."
  type        = string
  default     = "rg-dns-public"
}

variable "delegation_ttl" {
  description = "TTL in seconds of the NS delegation records in the parent zone."
  type        = number
  default     = 3600
}

variable "enable_telemetry" {
  description = "Enable AVM module telemetry. Off by default: no phone-home from this platform."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to all public DNS resources."
  type        = map(string)
  default     = {}
}
