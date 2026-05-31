resource "azurerm_data_factory" "adf" {
  name                = "adf-${var.name_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name

  identity { type = "SystemAssigned" }

  # Git integration — connect to your GitHub repo
  github_configuration {
    account_name    = var.github_account
    branch_name     = "main"
    git_url         = "https://github.com"
    repository_name = var.github_repo
    root_folder     = "/adf"
  }

  tags = var.tags
}

# ADF → ADLS access
resource "azurerm_role_assignment" "adf_adls" {
  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_data_factory.adf.identity[0].principal_id
}

# ADF → Key Vault access
resource "azurerm_role_assignment" "adf_keyvault" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_data_factory.adf.identity[0].principal_id
}

# ADF Linked Service — ADLS (using managed identity)
resource "azurerm_data_factory_linked_service_data_lake_storage_gen2" "adls" {
  name                 = "ls_adls_medallion"
  data_factory_id      = azurerm_data_factory.adf.id
  url     = var.primary_dfs_endpoint
  use_managed_identity = true
}

# ADF Linked Service — Azure SQL
resource "azurerm_data_factory_linked_service_azure_sql_database" "sql" {
  name            = "ls_sql_de"
  data_factory_id = azurerm_data_factory.adf.id
  connection_string = "data source=${var.sql_server_fqdn};initial catalog=${var.sql_database_name};user id=sqladmin;Password=${var.sql_admin_password};integrated security=False;encrypt=True;connection timeout=30"
}