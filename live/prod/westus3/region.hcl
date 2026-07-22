# CIDR assignments come from the IPAM table in docs/ipam.md.
locals {
  location     = "westus3"
  region_short = "wus3"

  hub_address_space       = ["10.110.0.0/22"]
  spoke_address_space     = ["10.111.0.0/16"]
  nodes_subnet_prefix     = "10.111.0.0/20"
  endpoints_subnet_prefix = "10.111.16.0/24"
}
