resource "azurerm_mssql_server" "sql_server" {
  name                         = "sqlsvr-${var.name_suffix}"
  resource_group_name          = var.resource_group_name
  location                     = var.location2
  version                      = "12.0"
  administrator_login          = "sqladmin"
  administrator_login_password = var.sql_admin_password

  tags = var.tags
}

resource "azurerm_mssql_database" "sql_db" {
  name      = "sqldb-${var.name_suffix}"
  server_id = azurerm_mssql_server.sql_server.id
  sku_name  = "GP_S_Gen5_1"

  auto_pause_delay_in_minutes = 60
  min_capacity                = 0.5

  tags = var.tags
}

# Allow Azure services (ADF, Synapse) to connect
resource "azurerm_mssql_firewall_rule" "azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.sql_server.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# Your laptop IP — get current IP first and paste here
resource "azurerm_mssql_firewall_rule" "my_laptop" {
  name             = "MyLaptop"
  server_id        = azurerm_mssql_server.sql_server.id
  start_ip_address = var.my_ip_address
  end_ip_address   = var.my_ip_address
}