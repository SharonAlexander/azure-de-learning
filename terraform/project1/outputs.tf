output "source_db_name" {
  value = module.source_sql.source_db_name
}

output "sql_server_fqdn" {
  value = module.source_sql.sql_server_fqdn
}

output "self_hosted_ir_name" {
  value = module.adf_extensions.self_hosted_ir_name
}

output "sql_linked_service_name" {
  value = module.adf_extensions.sql_linked_service_name
}

output "http_linked_service_name" {
  value = module.adf_extensions.http_linked_service_name
}

output "adls_linked_service_name" {
  value = module.adf_extensions.adls_linked_service_name
}

output "fincore_folders_created" {
  value = keys(azurerm_storage_data_lake_gen2_path.fincore_folders)
}