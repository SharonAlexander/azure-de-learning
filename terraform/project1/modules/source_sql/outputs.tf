output "source_db_name"       { value = azurerm_mssql_database.fincore_source.name }
output "sql_server_fqdn"      { value = data.azurerm_mssql_server.existing.fully_qualified_domain_name }
output "source_db_id"         { value = azurerm_mssql_database.fincore_source.id }