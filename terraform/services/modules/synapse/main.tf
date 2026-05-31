resource "azurerm_synapse_workspace" "synapse" {
  name                                 = "synapse-${var.name_suffix}"
  resource_group_name                  = var.resource_group_name
  location                             = var.location2
  storage_data_lake_gen2_filesystem_id = var.synapse_filesystem_id
  sql_administrator_login              = "sqladmin"
  sql_administrator_login_password     = var.sql_admin_password

  identity { type = "SystemAssigned" }

  tags = var.tags
}

# Allow Synapse to access ADLS
resource "azurerm_role_assignment" "synapse_adls" {
  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_synapse_workspace.synapse.identity[0].principal_id
  depends_on           = [azurerm_synapse_workspace.synapse]
}

# Synapse firewall — allow Azure services
resource "azurerm_synapse_firewall_rule" "azure_services" {
  name                 = "AllowAllWindowsAzureIps"
  synapse_workspace_id = azurerm_synapse_workspace.synapse.id
  start_ip_address     = "0.0.0.0"
  end_ip_address       = "0.0.0.0"
}

# Synapse firewall — your laptop
resource "azurerm_synapse_firewall_rule" "my_laptop" {
  name                 = "MyLaptop"
  synapse_workspace_id = azurerm_synapse_workspace.synapse.id
  start_ip_address     = var.my_ip_address
  end_ip_address       = var.my_ip_address
}