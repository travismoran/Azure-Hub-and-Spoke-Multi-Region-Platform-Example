module "log_analytics" {
  count = var.enable_log_analytics ? 1 : 0

  source  = "Azure/avm-res-operationalinsights-workspace/azurerm"
  version = "0.5.1"

  name                                      = "log-${var.name_prefix}-${var.environment}-${var.region_short}"
  location                                  = var.location
  resource_group_name                       = azurerm_resource_group.spoke.name
  log_analytics_workspace_sku               = "PerGB2018"
  log_analytics_workspace_retention_in_days = var.log_retention_days
  enable_telemetry                          = var.enable_telemetry
  tags                                      = var.tags
}
