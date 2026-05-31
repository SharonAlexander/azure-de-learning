variable "name_suffix"        { type = string }
variable "resource_group_name"{ type = string }
variable "location"           { type = string }
variable "location2"          { type = string }
variable "sql_admin_password" {
                                type = string
                                sensitive = true
                                }
variable "my_ip_address"      {
                                type = string
                                description = "Your laptop public IP"
                                }
variable "tags"               {
                                type = map(string)
                                default = {}
                                }