module "aks" {
  source  = "Azure/avm-res-containerservice-managedcluster/azurerm"
  version = "0.6.7"

  name                = local.cluster_name
  location            = var.location
  parent_id           = azurerm_resource_group.spoke.id
  dns_prefix          = local.cluster_name
  kubernetes_version  = var.kubernetes_version
  node_resource_group = "rg-aks-nodes-${var.environment}-${var.region_short}"
  enable_telemetry    = var.enable_telemetry
  tags                = var.tags

  sku = {
    name = "Base"
    tier = var.aks_sku_tier
  }

  aad_profile = {
    managed                = true
    enable_azure_rbac      = true
    admin_group_object_ids = var.admin_group_object_ids
  }

  api_server_access_profile = (var.private_cluster_enabled || length(var.api_server_authorized_ip_ranges) > 0) ? {
    enable_private_cluster = var.private_cluster_enabled ? true : null
    authorized_ip_ranges   = var.private_cluster_enabled ? null : var.api_server_authorized_ip_ranges
  } : null

  oidc_issuer_profile = {
    enabled = var.enable_workload_identity
  }

  security_profile = {
    workload_identity = var.enable_workload_identity ? { enabled = true } : null
    defender = var.enable_defender ? {
      log_analytics_workspace_resource_id = module.log_analytics[0].resource_id
      security_monitoring                 = { enabled = true }
    } : null
  }

  network_profile = {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = var.network_policy
    outbound_type       = var.outbound_type
    load_balancer_sku   = "standard"
    pod_cidr            = var.pod_cidr
    service_cidr        = var.service_cidr
    dns_service_ip      = var.dns_service_ip
  }

  default_agent_pool = {
    name                = "system"
    vm_size             = var.system_node_pool.vm_size
    enable_auto_scaling = true
    count_of            = var.system_node_pool.min_count
    min_count           = var.system_node_pool.min_count
    max_count           = var.system_node_pool.max_count
    os_disk_size_gb     = var.system_node_pool.os_disk_size_gb
    availability_zones  = var.system_node_pool.availability_zones
    vnet_subnet_id      = module.spoke_vnet.subnets["aks_nodes"].resource_id
    node_taints         = var.system_node_pool.critical_addons_only ? ["CriticalAddonsOnly=true:NoSchedule"] : null
    upgrade_settings    = { max_surge = "10%" }
  }

  agent_pools = {
    for name, pool in var.user_node_pools : name => {
      name                      = name
      mode                      = "User"
      vm_size                   = pool.vm_size
      enable_auto_scaling       = true
      count_of                  = pool.min_count
      min_count                 = pool.min_count
      max_count                 = pool.max_count
      os_disk_size_gb           = pool.os_disk_size_gb
      availability_zones        = pool.availability_zones
      vnet_subnet_id            = module.spoke_vnet.subnets["aks_nodes"].resource_id
      node_labels               = pool.node_labels
      node_taints               = length(pool.node_taints) > 0 ? pool.node_taints : null
      scale_set_priority        = pool.priority == "Spot" ? "Spot" : null
      scale_set_eviction_policy = pool.priority == "Spot" ? "Delete" : null
      spot_max_price            = pool.priority == "Spot" ? pool.spot_max_price : null
    }
  }

  addon_profile_azure_policy = var.enable_azure_policy ? { enabled = true } : null

  addon_profile_oms_agent = var.enable_container_insights ? {
    enabled = true
    config = {
      log_analytics_workspace_resource_id = module.log_analytics[0].resource_id
      use_aad_auth                        = true
    }
  } : null
  onboard_monitoring = var.enable_container_insights
}
