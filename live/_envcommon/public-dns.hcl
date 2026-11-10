# Shared configuration for the tenant-level public DNS unit
# (live/platform/dns): azure.<org domain> plus one delegated child zone per
# environment - Azure environments and external ones (local clusters) alike.
# No dependencies; every aks-spoke depends on it for its environment's zone
# ID. Applied once, before any environment.

locals {
  platform = read_terragrunt_config(find_in_parent_folders("platform.hcl")).locals
  common   = read_terragrunt_config(find_in_parent_folders("root.hcl")).locals
}

terraform {
  source = "${get_repo_root()}/modules/public-dns"
}

inputs = {
  enabled      = local.platform.enable_public_dns
  parent_zone  = local.platform.public_dns_parent_zone
  environments = concat(local.platform.environments, local.platform.external_environments)
  location     = local.platform.avnm_location

  tags = merge(local.common.common_tags, { Environment = "platform" })
}
