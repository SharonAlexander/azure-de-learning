terraform {
  required_version = ">= 1.5"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
  }

  # Remote state — same container as core/services, different key
  backend "azurerm" {
    resource_group_name  = "rg-delearn-dev"
    storage_account_name = "sadelearnnew0001"
    container_name       = "tfstate"
    key                  = "project1.tfstate"
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = false
    }
  }
}

locals {
  name_suffix = "${var.project}-${var.environment}"
  tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
    component   = "phase3-project1"
  }
}

# Fetch current public IP for firewall rules
data "http" "my_ip" {
  url = "https://api.ipify.org"
}

# ── Source SQL module ──────────────────────────────────────
module "source_sql" {
  source                   = "./modules/source_sql"
  resource_group_name      = var.resource_group_name
  existing_sql_server_name = var.existing_sql_server_name
  my_ip_address            = trimspace(data.http.my_ip.response_body)
  tags                     = local.tags
}

# ── Key Vault secret — SQL password ───────────────────────
# Store fincore SQL password in existing Key Vault
# ADF linked service reads it from here — no plaintext passwords in ADF
resource "azurerm_key_vault_secret" "fincore_sql_password" {
  name         = "fincore-sql-password"
  value        = var.sql_admin_password
  key_vault_id = var.existing_key_vault_id

  tags = local.tags
}

# ── Key Vault secret — storage account key ────────────────
# Used by ADF Self-hosted IR when connecting to ADLS
# Managed identity is preferred but Self-hosted IR needs explicit credential
data "azurerm_storage_account" "adls" {
  name                = var.existing_storage_account_name
  resource_group_name = var.resource_group_name
}

resource "azurerm_key_vault_secret" "adls_key" {
  name         = "adls-storage-key"
  value        = data.azurerm_storage_account.adls.primary_access_key
  key_vault_id = var.existing_key_vault_id

  tags = local.tags
}

# ── ADF extensions module ──────────────────────────────────
module "adf_extensions" {
  source                        = "./modules/adf_extensions"
  existing_adf_id               = var.existing_adf_id
  existing_key_vault_id         = var.existing_key_vault_id
  sql_server_fqdn               = module.source_sql.sql_server_fqdn
  existing_storage_account_name = var.existing_storage_account_name
  tags                          = local.tags

  depends_on = [
    azurerm_key_vault_secret.fincore_sql_password,
    module.source_sql
  ]
}

# ── ADLS folders for project1 ─────────────────────────────
# New subfolders inside existing medallion container
locals {
  fincore_folders = [
    "raw/fincore/transactions",
    "raw/fincore/accounts",
    "raw/fincore/customers",
    "raw/fincore/instruments",
    "raw/fincore/market_prices",
    "raw/fincore/trades",
    "bronze/fincore",
    "silver/fincore",
    "gold/fincore",
    "checkpoints/fincore"
  ]
}

resource "azurerm_storage_data_lake_gen2_path" "fincore_folders" {
  for_each           = toset(local.fincore_folders)
  path               = each.value
  filesystem_name    = "medallion"
  storage_account_id = var.existing_adls_id
  resource           = "directory"
}