variable "resource_group_name" {
  description = "Existing resource group from core layer"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus2"
}

variable "project" {
  description = "Project identifier"
  type        = string
  default     = "fincore"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

# Existing resources from core + services layers
variable "existing_sql_server_name" {
  description = "Existing SQL Server name from services layer (sqlsvr-delearn-dev)"
  type        = string
}

variable "existing_adf_id" {
  description = "Existing ADF resource ID from services layer"
  type        = string
}

variable "existing_adf_name" {
  description = "Existing ADF name from services layer"
  type        = string
}

variable "existing_key_vault_id" {
  description = "Existing Key Vault ID from core layer"
  type        = string
}

variable "existing_key_vault_name" {
  description = "Existing Key Vault name from core layer"
  type        = string
}

variable "existing_storage_account_name" {
  description = "Existing ADLS storage account name from core layer"
  type        = string
}

variable "existing_adls_id" {
  description = "Existing ADLS resource ID from core layer"
  type        = string
}

variable "sql_admin_password" {
  description = "SQL admin password — same as existing SQL Server"
  type        = string
  sensitive   = true
}
