# main.tf — root module

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  # Store state in Azure Storage (not local) — required for team projects
  # You'll set this up in Task 2 — leave commented for now
  backend "azurerm" {
    resource_group_name  = "rg-de-learning-tf"
    storage_account_name = "sadelearntf0001"
    container_name       = "tfstate"
    key                  = "de-learning.tfstate"
  }
}

provider "azurerm" {
  features {}
}

module "storage" {
  source = "./modules/storage"

  storage_account_name = var.storage_account_name
  resource_group_name  = azurerm_resource_group.rg.name
  location             = azurerm_resource_group.rg.location
  containers           = ["medallion", "synapse", "tfstate"]

  tags = {
    environment = var.environment
    managed_by  = "terraform"
  }
}