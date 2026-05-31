variable "name_suffix"          { type = string }
variable "resource_group_name"  { type = string }
variable "location"             { type = string }
variable "storage_account_id"   { type = string }
variable "primary_dfs_endpoint" { type = string }
variable "key_vault_id"         { type = string }
variable "sql_server_fqdn"      { type = string }
variable "sql_database_name"    { type = string }
variable "sql_admin_password"   {
                                    type = string
                                    sensitive = true
                                    }
variable "github_account"       { type = string }
variable "github_repo"          { type = string }
variable "tags"                 {
                                    type = map(string)
                                    default = {}
                                    }