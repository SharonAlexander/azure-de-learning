# Read from Layer 1 outputs
variable "resource_group_name"        { type = string }
variable "location"                   { type = string }
variable "location2"                  { type = string }
variable "storage_account_name"       { type = string }
variable "storage_account_id"         { type = string }
variable "access_connector_id"        { type = string }
variable "key_vault_id"               { type = string }

# Service-specific
variable "project"                    {
                                        type = string
                                        default = "delearn"
                                        }
variable "environment"                {
                                        type = string
                                        default = "dev"
                                        }
variable "sql_admin_password"         {
                                        type = string
                                        sensitive = true
                                        }
variable "databricks_sku"             {
                                        type = string
                                        default = "premium"
                                        }