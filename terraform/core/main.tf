terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  # Remote state — uncomment after first apply
  # backend "azurerm" {
  #   resource_group_name  = "rg-delearn-dev" 
  #   storage_account_name = "sadelearnnew0001"
  #   container_name       = "tfstate"
  #   key                  = "core.tfstate"
  # }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
}

locals {
  name_suffix = "${var.project}-${var.environment}"
  tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  }
}

# ── Resource Group ─────────────────────────────────────────
resource "azurerm_resource_group" "rg" {
  name     = "rg-${local.name_suffix}"
  location = var.location
  tags     = local.tags
}

# ── Access Connector for Databricks ───────────────────────
resource "azurerm_databricks_access_connector" "ac" {
  name                = "ac-${local.name_suffix}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  identity { type = "SystemAssigned" }
  tags = local.tags
}

# ── Storage module ─────────────────────────────────────────
module "storage" {
  source               = "./modules/storage"
  storage_account_name = var.storage_account_name
  resource_group_name  = azurerm_resource_group.rg.name
  location             = azurerm_resource_group.rg.location
  tags                 = local.tags
}

# ── RBAC: Access Connector → ADLS ─────────────────────────
resource "azurerm_role_assignment" "ac_adls" {
  scope                = module.storage.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_databricks_access_connector.ac.identity[0].principal_id
  depends_on           = [module.storage, azurerm_databricks_access_connector.ac]
}

# ── Key Vault module ───────────────────────────────────────
module "keyvault" {
  source                      = "./modules/keyvault"
  keyvault_name               = var.keyvault_name
  resource_group_name         = azurerm_resource_group.rg.name
  location                    = azurerm_resource_group.rg.location
  tenant_id                   = var.tenant_id
  my_object_id                = var.my_object_id
  storage_account_primary_key = module.storage.storage_account_id # placeholder — see note below
  tags                        = local.tags
  depends_on                  = [module.storage]
}