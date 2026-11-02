# CIDR assignments come from the IPAM table in docs/ipam.md.
locals {
  location     = "eastus2"
  region_short = "eus2"

  hub_address_space = ["10.1.4.0/22"]

  # Pool every AKS stamp in this env/region takes its /22 from: allocated by
  # AVNM IPAM when enable_avnm is on, otherwise the first /22 is used
  # statically. 64 stamps per /16. Must sit inside the region's root pool
  # (live/platform/platform.hcl).
  stamp_pool_prefix = "10.33.0.0/16"
}
