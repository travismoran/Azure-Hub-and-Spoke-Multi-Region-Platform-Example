variable "enabled" {
  description = <<DESC
Deploy the network platform (Azure Virtual Network Manager, IPAM pools, the
stamp network groups, the global meshes and security admin rules). The AVNM
instance and empty pools cost nothing; AVNM bills per managed VNet (~$0.10/hr
for every VNet that has a deployed configuration) and IPAM bills per active
IP, so cost only starts when an environment with enable_avnm = true applies
stamps. When false this module creates nothing and every output is
null/empty.
DESC
  type        = bool
  default     = false
}

variable "location" {
  description = "Home region of the AVNM instance and its resource group. Pools and commits are per region (see regions)."
  type        = string
}

variable "management_group_id" {
  description = <<DESC
Resource ID of the management group the AVNM instance and the membership
policies are scoped to (every subscription beneath it is covered). Null
scopes both to the subscription this module deploys into instead - the
single-subscription mode, where that subscription holds stamps as well.
DESC
  type        = string
  default     = null
}

variable "regions" {
  description = <<DESC
Every region of the platform, keyed by short region code. One root IPAM pool
per region over root_pool_prefix; environment pools nest inside it, so each
environment's stamp_pool_prefix must sit within its region's root. One AVNM
commit per region per scope.
DESC
  type = map(object({
    location         = string
    root_pool_prefix = string
  }))

  validation {
    condition     = alltrue([for r in var.regions : can(cidrhost(r.root_pool_prefix, 0))])
    error_message = "Every root_pool_prefix must be a valid CIDR."
  }
}

variable "environments" {
  description = <<DESC
Every environment, keyed by name, with its per-region stamp pool and hub
ranges (keys of regions must exist in var.regions). enabled = whether the
environment's stamps are IPAM-allocated and meshed (its env.hcl
enable_avnm): pools, network group, mesh and rules exist only for enabled
environments. Disabled environments still contribute their stamp pools to
the other environments' deny rules, because their stamps use those ranges
statically.
DESC
  type = map(object({
    enabled = bool
    regions = map(object({
      stamp_pool_prefix = string
      hub_address_space = list(string)
    }))
  }))

  validation {
    condition     = alltrue(flatten([for e in var.environments : [for r in e.regions : can(cidrhost(r.stamp_pool_prefix, 0))]]))
    error_message = "Every stamp_pool_prefix must be a valid CIDR."
  }
}

variable "high_risk_inbound_ports" {
  description = "TCP ports denied inbound from the Internet service tag on every stamp VNet."
  type        = list(string)
  default     = ["22", "3389", "445", "1433"]
}

variable "tags" {
  description = "Tags applied to all network platform resources."
  type        = map(string)
  default     = {}
}
