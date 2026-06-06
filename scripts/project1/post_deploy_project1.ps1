<#
.SYNOPSIS
    Post-deploy setup for Phase 3 Project 1 — FinCore Financial Lakehouse
    Run after terraform apply completes.

.PARAMETER ResourceGroup
    Resource group name (rg-delearn-dev)

.PARAMETER SqlServer
    SQL Server name without .database.windows.net suffix

.PARAMETER KeyVaultName
    Key Vault name for storing secrets

.EXAMPLE
    .\post_deploy_project1.ps1 `
        -ResourceGroup 'rg-delearn-dev' `
        -SqlServer 'sqlsvr-delearn-dev' `
        -KeyVaultName 'kv-delearn-0001'
#>

param(
    [Parameter(Mandatory)][string]$ResourceGroup,
    [Parameter(Mandatory)][string]$SqlServer,
    [Parameter(Mandatory)][string]$KeyVaultName
)

$ErrorActionPreference = 'Stop'
$SourceDb = 'sqldb-fincore-source'
$SqlFqdn  = '$SqlServer.database.windows.net'

Write-Host '`n=====================================' -ForegroundColor Cyan
Write-Host '  Project 1 Post-Deploy Setup' -ForegroundColor Cyan
Write-Host '=====================================' -ForegroundColor Cyan

# ── Step 1: Verify source database exists ─────────────────
Write-Host '`n[1/4] Verifying source database...' -ForegroundColor Yellow
$dbCheck = az sql db show `
    --name $SourceDb `
    --server $SqlServer `
    --resource-group $ResourceGroup `
    --query 'name' --output tsv 2>$null

if ($dbCheck -eq $SourceDb) {
    Write-Host '      ✓ $SourceDb exists and is reachable' -ForegroundColor Green
} else {
    Write-Host '      ✗ Database not found — check Terraform apply succeeded' -ForegroundColor Red
    exit 1
}

# ── Step 2: Verify Key Vault secrets were created ─────────
Write-Host '`n[2/4] Verifying Key Vault secrets...' -ForegroundColor Yellow
$secrets = @('fincore-sql-password', 'adls-storage-key')
foreach ($secret in $secrets) {
    $check = az keyvault secret show `
        --vault-name $KeyVaultName `
        --name $secret `
        --query 'name' --output tsv 2>$null
    if ($check) {
        Write-Host '      ✓ Secret exists: $secret' -ForegroundColor Green
    } else {
        Write-Host '      ✗ Secret missing: $secret' -ForegroundColor Red
    }
}

# ── Step 3: Verify ADLS folders exist ─────────────────────
Write-Host '`n[3/4] Verifying ADLS folder structure...' -ForegroundColor Yellow
$storageAccount = az storage account list `
    --resource-group $ResourceGroup `
    --query '[?tags.project=='fincore' || contains(name,'delearn')].name | [0]' `
    --output tsv

# Get storage account name from resource group
$storageAccount = az storage account list `
    --resource-group $ResourceGroup `
    --query '[0].name' --output tsv

$expectedFolders = @(
    'raw/fincore/transactions',
    'raw/fincore/accounts',
    'raw/fincore/customers',
    'raw/fincore/instruments',
    'raw/fincore/market_prices',
    'raw/fincore/trades',
    'bronze/fincore',
    'silver/fincore',
    'gold/fincore',
    'checkpoints/fincore'
)

foreach ($folder in $expectedFolders) {
    $exists = az storage fs directory exists `
        --name $folder `
        --file-system medallion `
        --account-name $storageAccount `
        --auth-mode login `
        --query 'exists' --output tsv 2>$null
    if ($exists -eq 'true') {
        Write-Host '      ✓ $folder' -ForegroundColor Green
    } else {
        Write-Host '      ✗ Missing: $folder' -ForegroundColor Red
    }
}

# ── Step 4: Install Self-hosted IR on laptop ──────────────
Write-Host '`n[4/4] Self-hosted Integration Runtime setup...' -ForegroundColor Yellow
Write-Host '      Self-hosted IR requires manual installation.' -ForegroundColor White
Write-Host '      Follow these steps:' -ForegroundColor White
Write-Host ''
Write-Host '      1. Open Azure Portal → ADF Studio → adf-delearn-dev' -ForegroundColor White
Write-Host '      2. Manage → Integration runtimes → ir-selfhosted-fincore' -ForegroundColor White
Write-Host '      3. Click 'Launch Express Setup' → run the installer on this laptop' -ForegroundColor White
Write-Host '      4. After install, status should show 'Running'' -ForegroundColor White
Write-Host ''
Write-Host '      OR use the PowerShell install method:' -ForegroundColor White
Write-Host '      Get auth key from ADF → run:' -ForegroundColor White
Write-Host '      .\microsoft_integration_runtime_install.ps1 -AuthKey <key>' -ForegroundColor White

Write-Host '`n=====================================' -ForegroundColor Cyan
Write-Host '  Post-deploy complete' -ForegroundColor Cyan
Write-Host '  Next: run scripts/project1/seed_source_db.sql' -ForegroundColor White
Write-Host '=====================================' -ForegroundColor Cyan
