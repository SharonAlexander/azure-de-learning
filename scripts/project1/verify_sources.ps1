<#
.SYNOPSIS
    Verifies all three data sources are ready before ADF pipelines run.

.PARAMETER SqlServer
    SQL Server FQDN without .database.windows.net
.PARAMETER StorageAccount
    ADLS Gen2 storage account name

.EXAMPLE
    .\verify_sources.ps1 `
        -SqlServer 'sqlsvr-delearn-dev' `
        -StorageAccount 'sadelearnnew0001'
#>

param(
    [Parameter(Mandatory)][string]$SqlServer,
    [Parameter(Mandatory)][string]$StorageAccount
)

$ErrorActionPreference = 'Continue'
$AllPassed = $true
$pass = "[PASS]"
$fail = "[FAIL]"

Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "  Component 2 Source Verification" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan

# ── Check 1: SQL Source DB ────────────────────────────────
Write-Host ""
Write-Host "[1/3] Verifying SQL source database..." -ForegroundColor Yellow

$tables = @('dim_instruments', 'dim_customers', 'dim_accounts', 'fact_transactions')
$expectedCounts = @{
    'dim_instruments'   = 10
    'dim_customers'     = 10
    'dim_accounts'      = 12
    'fact_transactions' = 20
}

# Prompt once for SQL password
$SqlPasswordPlain = Read-Host "Enter SQL password for sqladmin"

foreach ($table in $tables) {
    try {
        $result = Invoke-Sqlcmd `
            -ServerInstance ($SqlServer + ".database.windows.net") `
            -Database "sqldb-fincore-source" `
            -Username "sqladmin" `
            -Password $SqlPasswordPlain `
            -Query ("SELECT COUNT(*) AS cnt FROM dbo." + $table) `
            -ErrorAction Stop

        $count = $result.cnt
        $expected = $expectedCounts[$table]

        if ([int]$count -ge $expected) {
            Write-Host ("      " + $pass + " " + $table + ": " + $count + " rows") -ForegroundColor Green
        } else {
            Write-Host ("      " + $fail + " " + $table + ": " + $count + " rows (expected >= " + $expected + ")") -ForegroundColor Red
            $AllPassed = $false
        }
    } catch {
        Write-Host ("      " + $fail + " Could not query " + $table + ": " + $_) -ForegroundColor Red
        $AllPassed = $false
    }
}

# ── Check 2: REST API ─────────────────────────────────────
Write-Host ""
Write-Host "[2/3] Verifying REST API simulator..." -ForegroundColor Yellow

try {
    $health = Invoke-RestMethod `
        -Uri 'http://localhost:5000/api/v1/health' `
        -TimeoutSec 5
    Write-Host ("      " + $pass + " API health: " + $health.status) -ForegroundColor Green

    $prices = Invoke-RestMethod `
        -Uri 'http://localhost:5000/api/v1/market-prices?date=2024-01-02' `
        -TimeoutSec 5
    Write-Host ("      " + $pass + " Market prices endpoint: " + $prices.count + " instruments returned") -ForegroundColor Green

    $portfolios = Invoke-RestMethod `
        -Uri 'http://localhost:5000/api/v1/portfolios/all?date=2024-01-02' `
        -TimeoutSec 5
    Write-Host ("      " + $pass + " Portfolios endpoint: " + $portfolios.count + " accounts returned") -ForegroundColor Green

} catch {
    Write-Host ("      " + $fail + " API not reachable -- is api_simulator.py running?") -ForegroundColor Red
    Write-Host "        Start with: python scripts\project1\api_simulator.py" -ForegroundColor White
    $AllPassed = $false
}

# ── Check 3: CSV files in ADLS ────────────────────────────
Write-Host ""
Write-Host "[3/3] Verifying trade CSV files in ADLS..." -ForegroundColor Yellow

$expectedPaths = @(
    'raw/fincore/trades/2024/01',
    'raw/fincore/trades/2024/02',
    'raw/fincore/trades/2024/03'
)

foreach ($path in $expectedPaths) {
    try {
        $exists = az storage fs directory exists `
            --name $path `
            --file-system medallion `
            --account-name $StorageAccount `
            --auth-mode login `
            --query 'exists' `
            --output tsv 2>$null

        if ($exists -eq 'true') {
            $files = az storage fs file list `
                --path $path `
                --file-system medallion `
                --account-name $StorageAccount `
                --auth-mode login `
                --query 'length(@)' `
                --output tsv 2>$null
            Write-Host ("      " + $pass + " " + $path + " (" + $files + " file(s))") -ForegroundColor Green
        } else {
            Write-Host ("      " + $fail + " Missing: " + $path) -ForegroundColor Red
            $AllPassed = $false
        }
    } catch {
        Write-Host ("      " + $fail + " Error checking " + $path + ": " + $_) -ForegroundColor Red
        $AllPassed = $false
    }
}

# ── Summary ───────────────────────────────────────────────
Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
if ($AllPassed) {
    Write-Host ("  " + $pass + " All sources verified -- ready for Component 3") -ForegroundColor Green
} else {
    Write-Host ("  " + $fail + " Some checks failed -- fix before proceeding") -ForegroundColor Red
    Write-Host ""
    Write-Host "  Common fixes:" -ForegroundColor White
    Write-Host "  SQL: run scripts\project1\seed_source_db.sql" -ForegroundColor White
    Write-Host "  API: python scripts\project1\api_simulator.py" -ForegroundColor White
    Write-Host ("  CSV: python scripts\project1\generate_trade_csv.py --storage-account " + $StorageAccount) -ForegroundColor White
}
Write-Host "=====================================" -ForegroundColor Cyan