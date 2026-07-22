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
  network_policy                  = null

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
  enable_firewall   = false # ~$300+/mo even on Basic - off in dev
  firewall_sku_tier = "Basic"

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
