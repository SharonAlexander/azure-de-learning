output "synapse_workspace_id"               { value = azurerm_synapse_workspace.synapse.id }
output "synapse_workspace_name"             { value = azurerm_synapse_workspace.synapse.name }
output "synapse_serverless_sql_endpoint"    { value = azurerm_synapse_workspace.synapse.connectivity_endpoints["sqlOnDemand"] }