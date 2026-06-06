output "self_hosted_ir_name"     { value = azurerm_data_factory_integration_runtime_self_hosted.fincore_ir.name }
output "self_hosted_ir_id"       { value = azurerm_data_factory_integration_runtime_self_hosted.fincore_ir.id }
output "kv_linked_service_name"  { value = azurerm_data_factory_linked_service_key_vault.kv_ls.name }
output "sql_linked_service_name" { value = azurerm_data_factory_linked_service_azure_sql_database.fincore_source_ls.name }
output "http_linked_service_name"{ value = azurerm_data_factory_linked_service_web.http_api_ls.name }
output "adls_linked_service_name"{ value = azurerm_data_factory_linked_service_data_lake_storage_gen2.adls_ls.name }