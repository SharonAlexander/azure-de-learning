# post_deploy.ps1
# Run after both Terraform layers are applied
# Usage: .\post_deploy.ps1 -StorageAccount "sadelearnnew0001" -KeyVaultName "kv-delearn-0001" -ResourceGroup "rg-delearn-dev"

param(
    [string]$StorageAccount,
    [string]$KeyVaultName,
    [string]$ResourceGroup,
    [string]$SqlServer,
    [string]$SynapseWorkspace
)

Write-Host '`n=== Post-deploy setup ===' -ForegroundColor Cyan

# 1 — Push storage account key to Key Vault
Write-Host '`n[1/4] Storing ADLS key in Key Vault...' -ForegroundColor Yellow
$storageKey = az storage account keys list `
    --account-name $StorageAccount `
    --resource-group $ResourceGroup `
    --query "[0].value" `
    --output tsv

az keyvault secret set `
    --vault-name $KeyVaultName `
    --name "adls-primary-key" `
    --value $storageKey | Out-Null

Write-Host '      Done — adls-primary-key stored in Key Vault' -ForegroundColor Green

# 2 — Add your laptop IP to SQL firewall
Write-Host '`n[2/4] Adding laptop IP to SQL firewall...' -ForegroundColor Yellow
$myIp = (Invoke-RestMethod -Uri "https://api.ipify.org")
az sql server firewall-rule create `
    --resource-group $ResourceGroup `
    --server $SqlServer `
    --name "MyLaptop" `
    --start-ip-address $myIp `
    --end-ip-address $myIp | Out-Null
Write-Host '      Done — $myIp added to SQL firewall' -ForegroundColor Green

# 3 — Create SQL tables for ADF logging
Write-Host '`n[3/4] Creating SQL logging tables...' -ForegroundColor Yellow
$sqlScript = @"
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'pipeline_log')
BEGIN
    CREATE TABLE dbo.pipeline_log (
        log_id          INT IDENTITY(1,1) PRIMARY KEY,
        pipeline_name   VARCHAR(200),
        run_id          VARCHAR(200),
        source_name     VARCHAR(100),
        status          VARCHAR(50),
        rows_copied     INT,
        error_message   VARCHAR(MAX),
        run_start       DATETIME,
        run_end         DATETIME
    );
    PRINT 'pipeline_log created';
END

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'ingestion_config')
BEGIN
    CREATE TABLE dbo.ingestion_config (
        config_id       INT IDENTITY(1,1) PRIMARY KEY,
        source_name     VARCHAR(100),
        source_url      VARCHAR(500),
        target_folder   VARCHAR(200),
        target_filename VARCHAR(200),
        is_active       BIT DEFAULT 1
    );

    INSERT INTO dbo.ingestion_config (source_name, source_url, target_folder, target_filename)
    VALUES
        ('iris',    '/datasciencedojo/dataset/master/iris/iris.csv',     'raw/iris',    'iris.csv'),
        ('titanic', '/datasciencedojo/dataset/master/Titanic/Titanic.csv','raw/titanic','titanic.csv');

    PRINT 'ingestion_config created and seeded';
END

IF NOT EXISTS (SELECT * FROM sys.procedures WHERE name = 'usp_log_pipeline')
BEGIN
    EXEC('
    CREATE PROCEDURE dbo.usp_log_pipeline
        @pipeline_name  VARCHAR(200),
        @run_id         VARCHAR(200),
        @source_name    VARCHAR(100),
        @status         VARCHAR(50),
        @rows_copied    INT,
        @error_message  VARCHAR(MAX),
        @run_start      DATETIME,
        @run_end        DATETIME
    AS
    BEGIN
        INSERT INTO dbo.pipeline_log
            (pipeline_name, run_id, source_name, status, rows_copied, error_message, run_start, run_end)
        VALUES
            (@pipeline_name, @run_id, @source_name, @status, @rows_copied, @error_message, @run_start, @run_end)
    END
    ');
    PRINT 'usp_log_pipeline created';
END
"@

$sqlScript | Out-File -FilePath "$env:TEMP\setup.sql" -Encoding utf8
sqlcmd -S "$SqlServer.database.windows.net" `
       -d "sqldb-delearn-dev" `
       -U sqladmin `
       -i "$env:TEMP\setup.sql"
Write-Host '      Done — SQL tables created' -ForegroundColor Green

# 4 — Verify all resources are reachable
Write-Host '`n[4/4] Verifying resources...' -ForegroundColor Yellow

$resources = @(
    @{ Name = "Resource Group";   Command = { az group show --name $ResourceGroup --query name --output tsv } },
    @{ Name = "Storage Account";  Command = { az storage account show --name $StorageAccount --resource-group $ResourceGroup --query name --output tsv } },
    @{ Name = "Key Vault";        Command = { az keyvault show --name $KeyVaultName --resource-group $ResourceGroup --query name --output tsv } }
)

foreach ($r in $resources) {
    $result = & $r.Command
    if ($result) {
        Write-Host '      ✓ $($r.Name): $result' -ForegroundColor Green
    } else {
        Write-Host '      ✗ $($r.Name): NOT FOUND' -ForegroundColor Red
    }
}

Write-Host '`n=== Post-deploy complete ===' -ForegroundColor Cyan
Write-Host 'Next: run scripts\databricks_setup.py' -ForegroundColor White