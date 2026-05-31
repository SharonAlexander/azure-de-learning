variable "storage_account_name" { type = string }
variable "resource_group_name"  { type = string }
variable "location"             { type = string }
variable "replication_type"     { type = string  default = "LRS" }
variable "containers"           { type = list(string) }
variable "tags"                 { type = map(string) default = {} }