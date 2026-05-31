# variables.tf — all configurable values in one place

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-de-learning-tf"  # new RG for Terraform-managed resources
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus2"
}

variable "location2" {
  description = "Azure region"
  type        = string
  default     = "westus2"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "learning"
}

variable "storage_account_name" {
  description = "Name of the ADLS Gen2 storage account"
  type        = string
  # No default — must be supplied, globally unique
}

variable "adf_name" {
  description = "Name of the Azure Data Factory"
  type        = string
  default     = "adf-de-tf"
}

variable "sql_admin_password" {
  description = "Azure SQL admin password"
  type        = string
  sensitive   = true  # won't show in logs or plan output
}