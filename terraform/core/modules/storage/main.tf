resource "azurerm_storage_account" "adls" {
  name                     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = true # ADLS Gen2

  blob_properties {
    delete_retention_policy {
      days = 7 # soft delete — recover accidental deletes
    }
  }

  tags = var.tags
}

# Medallion container
resource "azurerm_storage_data_lake_gen2_filesystem" "medallion" {
  name               = "medallion"
  storage_account_id = azurerm_storage_account.adls.id
}

# Synapse container
resource "azurerm_storage_data_lake_gen2_filesystem" "synapse" {
  name               = "synapse"
  storage_account_id = azurerm_storage_account.adls.id
}

# Terraform state container
resource "azurerm_storage_data_lake_gen2_filesystem" "tfstate" {
  name               = "tfstate"
  storage_account_id = azurerm_storage_account.adls.id
}

# Medallion folders
locals {
  medallion_folders = ["raw", "bronze", "silver", "gold", "gold_parquet", "checkpoints"]
}

resource "azurerm_storage_data_lake_gen2_path" "medallion_folders" {
  for_each           = toset(local.medallion_folders)
  path               = each.value
  filesystem_name    = azurerm_storage_data_lake_gen2_filesystem.medallion.name
  storage_account_id = azurerm_storage_account.adls.id
  resource           = "directory"
}