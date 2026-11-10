# Azure Bastion for private clusters and jumpboxes. The Developer SKU needs
# no subnet or public IP (free, region-limited); every other SKU needs
# AzureBastionSubnet (/26, carved in main.tf) and a public IP the module
# creates.
module "bastion" {
  count = var.enable_bastion ? 1 : 0

  source = "git::https://github.com/Azure/terraform-azurerm-avm-res-network-bastionhost.git?ref=7c7d294caf81377671b99687aa75726e1072002e" # v0.9.0

  name      = "bas-hub-${var.environment}-${var.region_short}"
  location  = var.location
  parent_id = azurerm_resource_group.hub.id
  sku       = var.bastion_sku
  tags      = var.tags
  zones     = []

  virtual_network_id = var.bastion_sku == "Developer" ? module.hub.virtual_networks["hub"].id : null
  ip_configuration = var.bastion_sku == "Developer" ? null : {
    name             = "ipconfig"
    subnet_id        = module.hub.virtual_networks["hub"].subnet_ids["bastion"]
    create_public_ip = true
  }
}
