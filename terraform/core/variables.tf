variable "project" {
  type    = string
  default = "delearn"
}
variable "environment" {
  type    = string
  default = "dev"
}
variable "location" {
  type    = string
  default = "eastus2"
}
variable "storage_account_name" { type = string }
variable "keyvault_name" { type = string }
variable "tenant_id" { type = string }
variable "my_object_id" {
  type        = string
  description = "Your Azure AD Object ID — for Key Vault access policy"
}
