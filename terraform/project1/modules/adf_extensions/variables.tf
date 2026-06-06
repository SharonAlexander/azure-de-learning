variable "existing_adf_id"                { type = string }
variable "existing_key_vault_id"          { type = string }
variable "sql_server_fqdn"                { type = string }
variable "existing_storage_account_name"  { type = string }
variable "tags"                           { 
                                            type = map(string) 
                                            default = {} 
                                          }