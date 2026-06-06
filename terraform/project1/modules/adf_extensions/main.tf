# ── Self-hosted Integration Runtime ───────────────────────
# Registers the IR in ADF — you install the agent on your laptop separately
resource "azurerm_data_factory_integration_runtime_self_hosted" "fincore_ir" {
  name            = "ir-selfhosted-fincore"
  data_factory_id = var.existing_adf_id

  description = "Self-hosted IR for FinCore on-prem source simulation"
}

# ── Key Vault Linked Service ───────────────────────────────
# ADF needs a linked service to Key Vault before it can reference KV secrets
# in other linked services
resource "azurerm_data_factory_linked_service_key_vault" "kv_ls" {
  name            = "ls_keyvault"
  data_factory_id = var.existing_adf_id
  key_vault_id    = var.existing_key_vault_id
}

# ── Source SQL Linked Service (self-hosted IR) ─────────────
# Uses Key Vault secret reference for password — not plaintext
# connection_string only contains non-sensitive parts
resource "azurerm_data_factory_linked_service_azure_sql_database" "fincore_source_ls" {
  name            = "ls_fincore_source_sql"
  data_factory_id = var.existing_adf_id

  # Non-sensitive parts only in connection string
  # Password comes from Key Vault via key_vault_password block
  connection_string = "data source=${var.sql_server_fqdn};initial catalog=sqldb-fincore-source;user id=sqladmin;integrated security=False;encrypt=True;connection timeout=30"

  key_vault_password {
    linked_service_name = azurerm_data_factory_linked_service_key_vault.kv_ls.name
    secret_name         = "fincore-sql-password"
  }

  # Point to self-hosted IR for simulated on-prem connectivity
  integration_runtime_name = azurerm_data_factory_integration_runtime_self_hosted.fincore_ir.name

  depends_on = [
    azurerm_data_factory_linked_service_key_vault.kv_ls,
    azurerm_data_factory_integration_runtime_self_hosted.fincore_ir
  ]
}

# ── HTTP Linked Service for REST API simulator ─────────────
resource "azurerm_data_factory_linked_service_web" "http_api_ls" {
  name            = "ls_fincore_http_api"
  data_factory_id = var.existing_adf_id
  url             = "http://localhost:5000"   # Python Flask simulator on your laptop
  authentication_type = "Anonymous"
}

# ── ADLS Linked Service (managed identity) ────────────────
# Uses existing ADLS — managed identity auth, no credentials needed
resource "azurerm_data_factory_linked_service_data_lake_storage_gen2" "adls_ls" {
  name                 = "ls_adls_medallion"
  data_factory_id      = var.existing_adf_id
  url                  = "https://${var.existing_storage_account_name}.dfs.core.windows.net"
  use_managed_identity = true
}