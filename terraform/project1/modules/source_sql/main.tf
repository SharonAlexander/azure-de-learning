# ── Source database on existing SQL Server ─────────────────
# Creates a new database on the existing server — no new server needed
resource "azurerm_mssql_database" "fincore_source" {
  name      = "sqldb-fincore-source"
  server_id = data.azurerm_mssql_server.existing.id
  sku_name  = "GP_S_Gen5_1"   # serverless

  auto_pause_delay_in_minutes = 15
  min_capacity                = 0.5
  max_size_gb                 = 32

  tags = var.tags
}

# Read existing SQL Server — don't recreate it
data "azurerm_mssql_server" "existing" {
  name                = var.existing_sql_server_name
  resource_group_name = var.resource_group_name
}

# ── Firewall rule for laptop ───────────────────────────────
# SQL Server firewall rules apply at server level — affects all databases
resource "azurerm_mssql_firewall_rule" "laptop_fincore" {
  name             = "LaptopFincore"
  server_id        = data.azurerm_mssql_server.existing.id
  start_ip_address = var.my_ip_address
  end_ip_address   = var.my_ip_address
}