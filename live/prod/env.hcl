# prod environment: demonstrates the full enterprise feature set with every
# toggle on. This tree is intentionally plan-only in CI - applying it costs
# roughly $1,500+/month per region. See docs/costs.md.

locals {
  environment = "prod"
  name_prefix = get_env("TG_NAME_PREFIX", "demo")

  # --- Cluster ---
  kubernetes_version              = "1.32" # pin explicitly in prod
  aks_sku_tier                    = "Standard"
  private_cluster_enabled         = true
  api_server_authorized_ip_ranges = []
  admin_group_object_ids          = []
  # In prod, prefer a break-glass admin group over individual users.
  cluster_admin_principal_ids = compact([get_env("TG_CLUSTER_ADMIN_OBJECT_ID", "")])
  network_policy              = "cilium"

  system_node_pool = {
    vm_size              = "Standard_D4ds_v5"
    min_count            = 3
    max_count            = 5
    availability_zones   = ["1", "2", "3"]
    critical_addons_only = true
  }

  user_node_pools = {
    workload = {
      vm_size            = "Standard_D4as_v5"
      min_count          = 2
      max_count          = 6
      availability_zones = ["1", "2", "3"]
    }
  }

  # --- Hub ---
  enable_firewall   = true
  firewall_sku_tier = "Standard"
  # Intended end state is userDefinedRouting + enable_avnm_routing (all egress
  # inspected by the firewall); both stay off until verified in dev with a
  # firewall (ADR-016).
  aks_outbound_type   = "loadBalancer"
  enable_avnm_routing = false
  enable_dns_resolver = false
  enable_bastion      = false
  bastion_sku         = "Basic"

  # --- Network platform: AVNM + IPAM + global mesh (docs/network-platform.md) ---
  # prod stamps are IPAM-allocated and meshed; dev's pools are denied
  # inbound automatically (derived from every other env's region.hcl).
  enable_avnm         = true
  regions             = ["westus3", "eastus2"]
  stamp_prefix_length = 22
  enable_extra_stamps = false

  # --- Service discovery across stamps ---
  enable_private_dns = false
  # Workload identities per stamp (free): external-dns and cert-manager write
  # the environment's public zone, External Secrets reads the environment's
  # Key Vault (live/<env>/keyvault). Client IDs are stamp outputs that go into
  # the manifests repo overlays.
  enable_external_dns_identity     = true
  enable_cert_manager_identity     = true
  enable_external_secrets_identity = true
  # Environment Key Vault (modules/key-vault, ~$0.03/10k operations).
  key_vault_purge_protection         = true # prod: cannot be disabled once on
  key_vault_soft_delete_days         = 90
  enable_api_server_vnet_integration = false

  # --- Optional components ---
  enable_acr                = true
  acr_sku                   = "Premium"
  enable_log_analytics      = true
  log_retention_days        = 90
  enable_container_insights = true
  enable_managed_prometheus = true
  enable_defender           = true
  enable_azure_policy       = true
  enable_telemetry          = false
}
