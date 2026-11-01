variable "enabled" {
  description = <<DESC
Deploy the network platform (Azure Virtual Network Manager, IPAM pools, the
stamp network group, the global mesh and security admin rules). Off by
default: AVNM bills per managed VNet (~$0.10/hr for every VNet that has a
deployed configuration) and IPAM bills per active IP, so the cheap dev
footprint leaves it off and spokes use static addressing instead. When false
this module creates nothing and every output is null/empty.
DESC
  type        = bool
  default     = false
}

variable "environment" {
  description = "Environment name (e.g. dev, prod). Used in resource names and as the env tag the network group matches on."
  type        = string
}

variable "location" {
  description = "Home region of the AVNM instance and its resource group. Pools and deployments are per region (see regions)."
  type        = string
}

variable "regions" {
  description = <<DESC
Every region of this environment, keyed by short region code. One IPAM pool
and one AVNM commit per region. stamp_pool_prefix is the block AKS stamp
VNets in that region are allocated from; hub_address_space feeds the
always-allow security admin rule so hub firewalls/resolvers can reach stamps.
DESC
  type = map(object({
    location          = string
    stamp_pool_prefix = string
    hub_address_space = list(string)
  }))

  validation {
    condition     = alltrue([for r in var.regions : can(cidrhost(r.stamp_pool_prefix, 0))])
    error_message = "Every stamp_pool_prefix must be a valid CIDR."
  }
}

variable "security_admin_deny_inbound_from" {
  description = <<DESC
CIDRs denied inbound to every stamp VNet of this environment by a security
admin rule (evaluated before NSGs, cannot be overridden in a stamp). Intended
for the other environments' stamp pools, e.g. prod lists the dev pools so a
stray peering or on-prem route can never let nonprod reach prod. Empty by
default.
DESC
  type        = list(string)
  default     = []
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
