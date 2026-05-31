# resources.tf

# ── Resource Group ─────────────────────────────────────────
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    environment = var.environment
    managed_by  = "terraform"
  }
}

# ── ADLS Gen2 Storage Account ──────────────────────────────
resource "azurerm_storage_account" "adls" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  # This is what makes it ADLS Gen2
  is_hns_enabled = true

  tags = {
    environment = var.environment
    managed_by  = "terraform"
  }
}

# ── Storage Container ──────────────────────────────────────
resource "azurerm_storage_data_lake_gen2_filesystem" "medallion" {
  name               = "medallion"
  storage_account_id = azurerm_storage_account.adls.id
}

# ── Medallion folders ──────────────────────────────────────
resource "azurerm_storage_data_lake_gen2_path" "raw" {
  path               = "raw"
  filesystem_name    = azurerm_storage_data_lake_gen2_filesystem.medallion.name
  storage_account_id = azurerm_storage_account.adls.id
  resource           = "directory"
}

resource "azurerm_storage_data_lake_gen2_path" "bronze" {
  path               = "bronze"
  filesystem_name    = azurerm_storage_data_lake_gen2_filesystem.medallion.name
  storage_account_id = azurerm_storage_account.adls.id
  resource           = "directory"
}

resource "azurerm_storage_data_lake_gen2_path" "silver" {
  path               = "silver"
  filesystem_name    = azurerm_storage_data_lake_gen2_filesystem.medallion.name
  storage_account_id = azurerm_storage_account.adls.id
  resource           = "directory"
}

resource "azurerm_storage_data_lake_gen2_path" "gold" {
  path               = "gold"
  filesystem_name    = azurerm_storage_data_lake_gen2_filesystem.medallion.name
  storage_account_id = azurerm_storage_account.adls.id
  resource           = "directory"
}

# ── Azure Data Factory ─────────────────────────────────────
resource "azurerm_data_factory" "adf" {
  name                = var.adf_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  # System-assigned managed identity for ADF
  identity {
    type = "SystemAssigned"
  }

  tags = {
    environment = var.environment
    managed_by  = "terraform"
  }
}

# ── RBAC: Give ADF access to ADLS ─────────────────────────
resource "azurerm_role_assignment" "adf_adls_contributor" {
  scope                = azurerm_storage_account.adls.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_data_factory.adf.identity[0].principal_id

  depends_on = [
    azurerm_data_factory.adf,
    azurerm_storage_account.adls
  ]
}

# ── Azure SQL Server ───────────────────────────────────────
resource "azurerm_mssql_server" "sql_server" {
  name                         = "sqlsvr-de-tf-0002"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = var.location2
  version                      = "12.0"
  administrator_login          = "sqladmin"
  administrator_login_password = var.sql_admin_password

  tags = {
    environment = var.environment
    managed_by  = "terraform"
  }
}

# ── Azure SQL Database (serverless) ───────────────────────
resource "azurerm_mssql_database" "sql_db" {
  name      = "sqldb-de-learning-tf"
  server_id = azurerm_mssql_server.sql_server.id
  sku_name  = "GP_S_Gen5_1"  # Serverless, 1 vCore

  auto_pause_delay_in_minutes = 60
  min_capacity                = 0.5

  tags = {
    environment = var.environment
    managed_by  = "terraform"
  }
}

# ── SQL Firewall — allow Azure services ───────────────────
resource "azurerm_mssql_firewall_rule" "allow_azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.sql_server.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# ── Access Connector for Databricks ───────────────────────
resource "azurerm_databricks_access_connector" "ac" {
  name                = "ac-de-tf"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  identity {
    type = "SystemAssigned"
  }

  tags = {
    environment = var.environment
    managed_by  = "terraform"
  }
}

# ── RBAC: Give Access Connector access to ADLS ────────────
resource "azurerm_role_assignment" "ac_adls_contributor" {
  scope                = azurerm_storage_account.adls.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_databricks_access_connector.ac.identity[0].principal_id

  depends_on = [
    azurerm_databricks_access_connector.ac,
    azurerm_storage_account.adls
  ]
}

# ── Azure Databricks Workspace ─────────────────────────────
resource "azurerm_databricks_workspace" "adb" {
  name                = "adb-de-tf"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "premium"

  tags = {
    environment = var.environment
    managed_by  = "terraform"
  }
}