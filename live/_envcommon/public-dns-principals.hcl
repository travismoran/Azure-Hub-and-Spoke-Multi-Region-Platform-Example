# Shared configuration for the tenant-level DNS principals unit
# (live/platform/dns-principals): one zone-scoped service principal per
# external environment in platform.hcl (clusters outside Azure, which have
# no managed identity). AKS stamps never use this - they get workload
# identity in modules/aks-spoke/identity.tf. Depends on live/platform/dns
# for the zone IDs; the role assignments land on those zones, so the unit
# runs in the connectivity subscription (live/root.hcl).

locals {
  platform = read_terragrunt_config(find_in_parent_folders("platform.hcl")).locals
}

terraform {
  source = "${get_repo_root()}/modules//public-dns-principals" # double slash: copy all of modules/ so ../service-principal resolves
}

dependency "public_dns" {
  config_path = "../dns"

  # Shape must match modules/public-dns/outputs.tf exactly. Empty = no zones
  # yet, which yields no principals.
  mock_outputs = {
    env_zone_ids        = {}
    env_zone_names      = {}
    parent_name_servers = []
    parent_zone_id      = null
    parent_zone_name    = null
    resource_group_name = null
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  enabled = local.platform.enable_public_dns

  # Only external environments, and only those whose zone exists already
  # (apply live/platform/dns first; with mocks this is an empty map).
  zone_ids = {
    for env in local.platform.external_environments :
    env => dependency.public_dns.outputs.env_zone_ids[env]
    if contains(keys(dependency.public_dns.outputs.env_zone_ids), env)
  }

  secret_rotation_days          = local.platform.dns_principal_secret_days
  owner_service_principal_names = local.platform.dns_principal_owner_sp_names
}
