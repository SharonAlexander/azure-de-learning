# outputs.tf — values to display after apply

output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "storage_account_name" {
  value = azurerm_storage_account.adls.name
}

output "adf_name" {
  value = azurerm_data_factory.adf.name
}

output "adf_managed_identity" {
  description = "ADF managed identity — needed for RBAC assignments"
  value       = azurerm_data_factory.adf.identity[0].principal_id
}