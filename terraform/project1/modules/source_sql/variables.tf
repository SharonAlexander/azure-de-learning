variable "resource_group_name"      { type = string }
variable "existing_sql_server_name" { type = string }
variable "my_ip_address"            { type = string }
variable "tags"                     {
                                        type = map(string)
                                        default = {} 
                                    }