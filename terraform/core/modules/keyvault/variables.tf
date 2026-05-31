variable "keyvault_name" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "tenant_id" { type = string }
variable "my_object_id" { type = string }
variable "storage_account_primary_key" {
  type      = string
  sensitive = true
}
variable "tags" {
  type    = map(string)
  default = {}
}
