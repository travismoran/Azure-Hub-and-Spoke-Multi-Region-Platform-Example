locals {
  # null unless something in it is set: the AVM module dereferences the
  # object, and an all-null profile changes the API payload.
  api_server_access_profile = (var.private_cluster_enabled || length(var.api_server_authorized_ip_ranges) > 0 || var.enable_api_server_vnet_integration) ? {
    enable_private_cluster  = var.private_cluster_enabled ? true : null
    authorized_ip_ranges    = var.private_cluster_enabled || length(var.api_server_authorized_ip_ranges) == 0 ? null : var.api_server_authorized_ip_ranges
    enable_vnet_integration = var.enable_api_server_vnet_integration ? true : null
    subnet_id               = var.enable_api_server_vnet_integration ? module.subnet["apiserver"].resource_id : null
  } : null
}

module "aks" {
  source = "git::https://github.com/Azure/terraform-azurerm-avm-res-containerservice-managedcluster.git?ref=2d0302e9d8c450df2d1b257c32823b00b3557c96" # v0.6.7

  name                = local.cluster_name
  location            = var.location
  parent_id           = azurerm_resource_group.spoke.id
  dns_prefix          = local.cluster_name
  kubernetes_version  = var.kubernetes_version
  node_resource_group = "rg-aks-nodes-${var.environment}-${var.region_short}${local.suffix}"
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

  api_server_access_profile = local.api_server_access_profile

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
    network_dataplane   = var.network_policy == "cilium" ? "cilium" : null
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
    vnet_subnet_id      = module.subnet["aks-system"].resource_id
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
      vnet_subnet_id            = module.subnet["aks-user"].resource_id
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
  # onboard_monitoring wires Prometheus + container insights data collection;
  # it needs the Azure Monitor workspace, so it follows that toggle. The OMS
  # agent addon above is enough for container insights alone.
  onboard_monitoring      = var.enable_managed_prometheus
  prometheus_workspace_id = var.enable_managed_prometheus ? azurerm_monitor_workspace.prometheus[0].id : null
}

# BYO-VNet requirement: the cluster's control-plane identity must be able to
# join subnets (internal load balancers) and manage the node route table.
# Without these, internal LoadBalancer services stay <pending> with
# AuthorizationFailed events.
resource "azurerm_role_assignment" "aks_vnet_network_contributor" {
  scope                = module.spoke_vnet.resource_id
  role_definition_name = "Network Contributor"
  principal_id         = module.aks.identity_principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "aks_route_table_network_contributor" {
  count = var.firewall_private_ip != null ? 1 : 0

  scope                = azurerm_route_table.nodes[0].id
  role_definition_name = "Network Contributor"
  principal_id         = module.aks.identity_principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "cluster_admin" {
  for_each = var.cluster_admin_principal_ids

  scope                = module.aks.resource_id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = each.value
}
