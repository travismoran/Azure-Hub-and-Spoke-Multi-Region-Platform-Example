module "acr" {
  count = var.enable_acr ? 1 : 0

  source = "git::https://github.com/Azure/terraform-azurerm-avm-res-containerregistry-registry.git?ref=a3f2ae1622b43a69d1c8554beca673bb3fada65c" # v0.5.1

  name                = local.acr_name
  location            = var.location
  resource_group_name = azurerm_resource_group.spoke.name
  sku                 = var.acr_sku
  # The AVM module defaults to Premium + zone redundancy; Basic supports neither.
  zone_redundancy_enabled = false
  enable_telemetry        = var.enable_telemetry
  tags                    = var.tags
}

resource "azurerm_role_assignment" "kubelet_acr_pull" {
  count = var.enable_acr && var.acr_grant_kubelet_pull ? 1 : 0

  scope                = module.acr[0].resource_id
  role_definition_name = "AcrPull"
  principal_id         = module.aks.kubelet_identity.objectId
  principal_type       = "ServicePrincipal"
}
