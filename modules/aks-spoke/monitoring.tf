module "log_analytics" {
  count = var.enable_log_analytics ? 1 : 0

  source = "git::https://github.com/Azure/terraform-azurerm-avm-res-operationalinsights-workspace.git?ref=b4ffa3ff87ac09ff6de3b7014c44b4d213aa302b" # v0.5.1

  name                                      = "log-${var.name_prefix}-${var.environment}-${var.region_short}${local.suffix}"
  location                                  = var.location
  resource_group_name                       = azurerm_resource_group.spoke.name
  log_analytics_workspace_sku               = "PerGB2018"
  log_analytics_workspace_retention_in_days = var.log_retention_days
  enable_telemetry                          = var.enable_telemetry
  tags                                      = var.tags
}

# Managed Prometheus. No AVM module exists for Azure Monitor workspaces
# (checked 2026-11-07), so this is the plain resource. The AKS module's
# monitoring submodule (onboard_monitoring) requires it: without a workspace
# the first real prod plan failed with "prometheus_workspace_id may not be
# set to null".
resource "azurerm_monitor_workspace" "prometheus" {
  count = var.enable_managed_prometheus ? 1 : 0

  name                = "amw-${var.name_prefix}-${var.environment}-${var.region_short}${local.suffix}"
  location            = var.location
  resource_group_name = azurerm_resource_group.spoke.name
  tags                = var.tags
}
