# dev environment: every knob turned to the cheapest setting.
# Approximate cost with these defaults: ~$75-100/month per region.

locals {
  environment = "dev"
  name_prefix = get_env("TG_NAME_PREFIX", "demo")

  # --- Cluster ---
  kubernetes_version      = null # latest GA picked by Azure; fine for dev
  aks_sku_tier            = "Free"
  private_cluster_enabled = false
  # Lock the public API server down to your own IP (set TG_AUTHORIZED_IP).
  # Empty list = open API server; fine for throwaway clusters, but set it.
  api_server_authorized_ip_ranges = compact([get_env("TG_AUTHORIZED_IP", "")])
  admin_group_object_ids          = []
  # Who can kubectl: your own object id, via env var (never committed).
  #   az ad signed-in-user show --query id -o tsv
  cluster_admin_principal_ids = compact([get_env("TG_CLUSTER_ADMIN_OBJECT_ID", "")])
  network_policy              = null

  system_node_pool = {
    vm_size              = "Standard_B2ms" # 2 vCPU / 8 GiB burstable, ~$60/mo
    min_count            = 1
    max_count            = 2
    critical_addons_only = true
  }

  # One Spot pool for workloads: scales from zero, evictable, 70-90% cheaper.
  user_node_pools = {
    spot = {
      vm_size   = "Standard_D2as_v5"
      min_count = 0
      max_count = 2
      priority  = "Spot"
    }
  }

  # --- Hub ---
  # Firewalls cost ~$300/mo each even on Basic, so dev defaults to none -
  # regions are isolated and spokes egress via their load balancer. Set true
  # to enable cross-region hub-to-hub transit (see docs/architecture.md);
  # the UDRs, firewall routes, and transit rules all activate automatically.
  # Verified working 2026-07-21: .ai/test-results/2026-07-21-aks-e2e.md
  enable_firewall   = false
  firewall_sku_tier = "Basic"

  # --- Network platform: AVNM + IPAM + global mesh (docs/network-platform.md) ---
  # Azure Virtual Network Manager bills per managed VNet (~$0.10/hr for each
  # VNet with a deployed configuration) plus a small per-active-IP IPAM fee,
  # so dev leaves it off: each spoke gets a static /22 from region.hcl and
  # regions stay isolated (or transit via hub firewalls, enable_firewall).
  # Set true to allocate every spoke /22 from an IPAM pool and join all dev
  # spokes in one global mesh (direct cross-region cluster-to-cluster, no
  # firewall needed for east-west).
  enable_avnm         = false
  avnm_location       = "westus3"
  regions             = ["westus3", "eastus2"] # folders here holding a region.hcl
  stamp_prefix_length = 22
  # Other environments' stamp pools to deny inbound at the AVNM layer.
  security_admin_deny_inbound_from = []

  # --- Optional components (all the expensive telemetry/security is OFF) ---
  enable_acr                = true # Basic, ~$5/mo
  acr_sku                   = "Basic"
  enable_log_analytics      = false
  log_retention_days        = 30
  enable_container_insights = false
  enable_defender           = false
  enable_azure_policy       = false
  enable_telemetry          = false
}
