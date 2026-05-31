variable "name_suffix"            { type = string }
variable "resource_group_name"    { type = string }
variable "location2"               { type = string }
variable "storage_account_id"     { type = string }
variable "synapse_filesystem_id"  { type = string }
variable "sql_admin_password"     {
                                    type = string
                                    sensitive = true
                                    }
variable "my_ip_address"          { type = string }
variable "tags"                   {
                                    type = map(string)
                                    default = {}
                                    }