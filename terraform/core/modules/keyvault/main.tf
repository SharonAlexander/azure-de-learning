resource "azurerm_key_vault" "kv" {
  name                       = var.keyvault_name
  location                   = var.location
  resource_group_name        = var.resource_group_name
  tenant_id                  = var.tenant_id
  sku_name                   = "standard"
  purge_protection_enabled   = false # allow permanent delete for learning
  soft_delete_retention_days = 7

  # Access policy for your own account
  access_policy {
    tenant_id = var.tenant_id
    object_id = var.my_object_id

    secret_permissions = [
      "Get", "List", "Set", "Delete", "Purge"
    ]
  }

  tags = var.tags
}

# Store storage account key as a secret
resource "azurerm_key_vault_secret" "storage_key" {
  name         = "adls-primary-key"
  value        = var.storage_account_primary_key
  key_vault_id = azurerm_key_vault.kv.id
}
