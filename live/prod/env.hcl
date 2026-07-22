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

  # --- Optional components ---
  enable_acr                = true
  acr_sku                   = "Premium"
  enable_log_analytics      = true
  log_retention_days        = 90
  enable_container_insights = true
  enable_defender           = true
  enable_azure_policy       = true
  enable_telemetry          = false
}
