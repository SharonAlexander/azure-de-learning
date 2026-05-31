terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }

    http = {
        source  = "hashicorp/http"
        version = "~> 3.0"
    }
  }

  # Remote state for services layer
  # backend "azurerm" {
  #   resource_group_name  = "rg-delearn-dev"
  #   storage_account_name = "sadelearnnew0001"
  #   container_name       = "tfstate"
  #   key                  = "services.tfstate"
  # }
}

provider "azurerm" {
  features {}
}

locals {
  name_suffix = "${var.project}-${var.environment}"
  tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  }
  synapse_filesystem_id = "https://${var.storage_account_name}.dfs.core.windows.net/synapse"
}

# Get current public IP for firewall rules
data "http" "my_ip" {
  url = "https://api.ipify.org"
}

# ── SQL module ─────────────────────────────────────────────
module "sql" {
  source              = "./modules/sql"
  name_suffix         = local.name_suffix
  resource_group_name = var.resource_group_name
  location            = var.location
  location2           = var.location2
  sql_admin_password  = var.sql_admin_password
  my_ip_address       = data.http.my_ip.response_body
  tags                = local.tags
}

# ── ADF module ─────────────────────────────────────────────
module "adf" {
  source               = "./modules/adf"
  name_suffix          = local.name_suffix
  resource_group_name  = var.resource_group_name
  location             = var.location
  storage_account_id   = var.storage_account_id
  primary_dfs_endpoint = "https://${var.storage_account_name}.dfs.core.windows.net"
  key_vault_id         = var.key_vault_id
  sql_server_fqdn      = module.sql.sql_server_fqdn
  sql_database_name    = module.sql.sql_database_name
  sql_admin_password   = var.sql_admin_password
  github_account       = "your-github-username"   # replace
  github_repo          = "azure-de-learning"
  tags                 = local.tags
  depends_on           = [module.sql]
}

# ── Databricks module ──────────────────────────────────────
module "databricks" {
  source              = "./modules/databricks"
  name_suffix         = local.name_suffix
  resource_group_name = var.resource_group_name
  location            = var.location
  storage_account_id  = var.storage_account_id
  sku                 = var.databricks_sku
  tags                = local.tags
}

# ── Synapse module ─────────────────────────────────────────

module "synapse" {
  source                  = "./modules/synapse"
  name_suffix             = local.name_suffix
  resource_group_name     = var.resource_group_name
  location2                = var.location2
  storage_account_id      = var.storage_account_id
  synapse_filesystem_id   = local.synapse_filesystem_id
  sql_admin_password      = var.sql_admin_password
  my_ip_address           = data.http.my_ip.response_body
  tags                    = local.tags
}