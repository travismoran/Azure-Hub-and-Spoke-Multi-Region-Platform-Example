variable "environment" {
  description = "Environment name (e.g. dev, prod). Used in resource names."
  type        = string
}

variable "region_short" {
  description = "Short region code used in resource names (e.g. wus3, eus2)."
  type        = string
}

variable "location" {
  description = "Azure region for the hub resources."
  type        = string
}

variable "address_space" {
  description = "Address space of the hub virtual network (a /22 is plenty)."
  type        = list(string)

  validation {
    condition     = length(var.address_space) > 0
    error_message = "address_space must contain at least one CIDR."
  }
}

variable "enable_firewall" {
  description = <<DESC
Deploy an Azure Firewall in the hub. Disabled by default: even the Basic SKU
costs ~$300/month. When disabled the hub is just a peered virtual network,
and spokes egress directly through their AKS load balancer.
DESC
  type        = bool
  default     = false
}

variable "firewall_sku_tier" {
  description = "Azure Firewall SKU tier when enable_firewall is true. Basic is the cheapest (~$300/mo vs ~$900/mo for Standard)."
  type        = string
  default     = "Basic"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.firewall_sku_tier)
    error_message = "firewall_sku_tier must be Basic, Standard, or Premium."
  }
}

variable "firewall_subnet_prefix" {
  description = "CIDR for AzureFirewallSubnet. Defaults to the first /26 of the hub address space."
  type        = string
  default     = null
}

variable "firewall_management_subnet_prefix" {
  description = "CIDR for AzureFirewallManagementSubnet (required by the Basic SKU). Defaults to the second /26 of the hub address space."
  type        = string
  default     = null
}

variable "firewall_route_entries" {
  description = <<DESC
Extra routes for the firewall subnet's route table. Used for hub-to-hub
transit: point each remote spoke CIDR at the remote hub's firewall private IP.
DESC
  type = set(object({
    name                = string
    address_prefix      = string
    next_hop_ip_address = string
  }))
  default = []
}

variable "peer_hub" {
  description = <<DESC
Optional global VNet peering to another hub (both directions are created, so
define this on exactly ONE of the two hubs). Peering alone does not make
spoke-to-spoke traffic flow - that also needs firewalls and UDRs; see
docs/architecture.md.
DESC
  type = object({
    vnet_id             = string
    vnet_name           = string
    resource_group_name = string
  })
  default = null
}

variable "transit_cidrs" {
  description = "Source/destination CIDRs the firewall allows to transit between hubs and spokes."
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

variable "enable_telemetry" {
  description = "Enable AVM module telemetry. Off by default to avoid any phone-home from this example."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to all hub resources."
  type        = map(string)
  default     = {}
}
