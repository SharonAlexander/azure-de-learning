resource "azurerm_databricks_workspace" "adb" {
  name                = "adb-${var.name_suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.sku

  # Hybrid mode — deploys into your Azure subscription
  managed_resource_group_name = "rg-databricks-managed-${var.name_suffix}"

  tags = var.tags
}
