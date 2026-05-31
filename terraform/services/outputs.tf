output "sql_server_fqdn"                  { value = module.sql.sql_server_fqdn }
output "adf_name"                         { value = module.adf.adf_name }
output "databricks_workspace_url"         { value = module.databricks.workspace_url }
output "synapse_serverless_sql_endpoint"  { value = module.synapse.synapse_serverless_sql_endpoint }