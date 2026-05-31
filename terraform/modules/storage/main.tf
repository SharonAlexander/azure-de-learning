# modules/storage/main.tf

resource "azurerm_storage_account" "adls" {
  name                     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = var.replication_type
  account_kind             = "StorageV2"
  is_hns_enabled           = true

  tags = var.tags
}

resource "azurerm_storage_data_lake_gen2_filesystem" "container" {
  for_each           = toset(var.containers)
  name               = each.value
  storage_account_id = azurerm_storage_account.adls.id
}