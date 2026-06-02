-- ============================================================
-- synapse_setup.sql
-- Run against serverless endpoint:
-- synapse-delearn-dev-ondemand.sql.azuresynapse.net
-- Connect to: master first, then switch to gold_db
-- ============================================================

-- ── Step 1: Create database ────────────────────────────────
USE master;
GO

IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'gold_db')
BEGIN
    CREATE DATABASE gold_db;
    PRINT 'gold_db created';
END
ELSE
    PRINT 'gold_db already exists — skipping';
GO

USE gold_db;
GO

-- ── Step 2: Master key ─────────────────────────────────────
IF NOT EXISTS (
    SELECT * FROM sys.symmetric_keys
    WHERE name = '##MS_DatabaseMasterKey##'
)
BEGIN
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'YourStr0ngP@ssword!';
    PRINT 'Master key created';
END
ELSE
    PRINT 'Master key already exists — skipping';
GO

-- ── Step 3: Managed identity credential ───────────────────
IF NOT EXISTS (
    SELECT * FROM sys.database_scoped_credentials
    WHERE name = 'synapse_mi_credential'
)
BEGIN
    CREATE DATABASE SCOPED CREDENTIAL synapse_mi_credential
    WITH IDENTITY = 'Managed Identity';
    PRINT 'Credential created';
END
ELSE
    PRINT 'Credential already exists — skipping';
GO

-- ── Step 4: External data source ──────────────────────────
-- Replace sadelearnnew0001 with your actual storage account name
IF NOT EXISTS (
    SELECT * FROM sys.external_data_sources
    WHERE name = 'adls_medallion'
)
BEGIN
    CREATE EXTERNAL DATA SOURCE adls_medallion
    WITH (
        LOCATION   = 'https://sadelearnnew0001.dfs.core.windows.net/medallion',
        CREDENTIAL = synapse_mi_credential
    );
    PRINT 'External data source created';
END
ELSE
    PRINT 'External data source already exists — skipping';
GO

-- ── Step 5: External file format for Delta ─────────────────
-- This is the missing step — FILE_FORMAT = DeltaLakeFormat
-- references THIS named object. Must be created before external tables.
IF NOT EXISTS (
    SELECT * FROM sys.external_file_formats
    WHERE name = 'DeltaLakeFormat'
)
BEGIN
    CREATE EXTERNAL FILE FORMAT DeltaLakeFormat
    WITH (FORMAT_TYPE = DELTA);
    PRINT 'Delta external file format created';
END
ELSE
    PRINT 'DeltaLakeFormat already exists — skipping';
GO

-- ── Step 6: External file format for Parquet ──────────────
-- Needed if you want external tables over gold_parquet/ files
IF NOT EXISTS (
    SELECT * FROM sys.external_file_formats
    WHERE name = 'ParquetFormat'
)
BEGIN
    CREATE EXTERNAL FILE FORMAT ParquetFormat
    WITH (
        FORMAT_TYPE = PARQUET,
        DATA_COMPRESSION = 'org.apache.hadoop.io.compress.SnappyCodec'
    );
    PRINT 'Parquet external file format created';
END
ELSE
    PRINT 'ParquetFormat already exists — skipping';
GO

-- ── Step 7: External tables ────────────────────────────────
-- Two options depending on what files exist in your ADLS:
-- Option A: Delta tables (points to /gold/ Delta folders)
-- Option B: Parquet files (points to /gold_parquet/ export)
--
-- Use Option A if you ran the Databricks medallion notebooks
-- Use Option B if you ran the Parquet export from Week 5
-- Run only ONE option — not both for the same table name
-- ──────────────────────────────────────────────────────────

-- ── Option A: Delta external tables ───────────────────────

IF NOT EXISTS (SELECT * FROM sys.external_tables WHERE name = 'ext_daily_sales_summary')
BEGIN
    CREATE EXTERNAL TABLE ext_daily_sales_summary (
        sale_date           DATE,
        product             VARCHAR(200),
        region              VARCHAR(200),
        total_revenue       FLOAT,
        total_units         FLOAT,
        transaction_count   FLOAT,
        avg_discount_pct    FLOAT
    )
    WITH (
        LOCATION    = '/gold/daily_sales_summary/',
        DATA_SOURCE = adls_medallion,
        FILE_FORMAT = DeltaLakeFormat
    );
    PRINT 'ext_daily_sales_summary created (Delta)';
END
ELSE
    PRINT 'ext_daily_sales_summary already exists — skipping';
GO

IF NOT EXISTS (SELECT * FROM sys.external_tables WHERE name = 'ext_product_performance')
BEGIN
    CREATE EXTERNAL TABLE ext_product_performance (
        product                 VARCHAR(200),
        total_revenue           FLOAT,
        total_units             FLOAT,
        avg_transaction_value   FLOAT,
        transaction_count       FLOAT
    )
    WITH (
        LOCATION    = '/gold/product_performance/',
        DATA_SOURCE = adls_medallion,
        FILE_FORMAT = DeltaLakeFormat
    );
    PRINT 'ext_product_performance created (Delta)';
END
ELSE
    PRINT 'ext_product_performance already exists — skipping';
GO

IF NOT EXISTS (SELECT * FROM sys.external_tables WHERE name = 'ext_regional_performance')
BEGIN
    CREATE EXTERNAL TABLE ext_regional_performance (
        region              VARCHAR(200),
        total_revenue       FLOAT,
        transaction_count   FLOAT,
        avg_discount_pct    FLOAT
    )
    WITH (
        LOCATION    = '/gold/regional_performance/',
        DATA_SOURCE = adls_medallion,
        FILE_FORMAT = DeltaLakeFormat
    );
    PRINT 'ext_regional_performance created (Delta)';
END
ELSE
    PRINT 'ext_regional_performance already exists — skipping';
GO

-- ── Option B: Parquet external tables (use if Delta above fails) ──
-- Uncomment this block and comment out Option A if you prefer Parquet
-- These point to the gold_parquet/ export from the Databricks notebook

/*
IF NOT EXISTS (SELECT * FROM sys.external_tables WHERE name = 'ext_daily_sales_summary')
BEGIN
    CREATE EXTERNAL TABLE ext_daily_sales_summary (
        sale_date           DATE,
        product             VARCHAR(200),
        region              VARCHAR(200),
        total_revenue       FLOAT,
        total_units         FLOAT,
        transaction_count   FLOAT,
        avg_discount_pct    FLOAT
    )
    WITH (
        LOCATION    = '/gold_parquet/daily_sales_summary/',
        DATA_SOURCE = adls_medallion,
        FILE_FORMAT = ParquetFormat
    );
    PRINT 'ext_daily_sales_summary created (Parquet)';
END
GO

IF NOT EXISTS (SELECT * FROM sys.external_tables WHERE name = 'ext_product_performance')
BEGIN
    CREATE EXTERNAL TABLE ext_product_performance (
        product                 VARCHAR(200),
        total_revenue           FLOAT,
        total_units             FLOAT,
        avg_transaction_value   FLOAT,
        transaction_count       FLOAT
    )
    WITH (
        LOCATION    = '/gold_parquet/product_performance/',
        DATA_SOURCE = adls_medallion,
        FILE_FORMAT = ParquetFormat
    );
    PRINT 'ext_product_performance created (Parquet)';
END
GO

IF NOT EXISTS (SELECT * FROM sys.external_tables WHERE name = 'ext_regional_performance')
BEGIN
    CREATE EXTERNAL TABLE ext_regional_performance (
        region              VARCHAR(200),
        total_revenue       FLOAT,
        transaction_count   FLOAT,
        avg_discount_pct    FLOAT
    )
    WITH (
        LOCATION    = '/gold_parquet/regional_performance/',
        DATA_SOURCE = adls_medallion,
        FILE_FORMAT = ParquetFormat
    );
    PRINT 'ext_regional_performance created (Parquet)';
END
GO
*/

-- ── Step 8: Dashboard view ─────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.views WHERE name = 'vw_sales_dashboard')
BEGIN
    EXEC('
    CREATE VIEW vw_sales_dashboard AS
    SELECT
        d.sale_date,
        d.product,
        d.region,
        d.total_revenue,
        d.total_units,
        d.transaction_count,
        d.avg_discount_pct,
        p.avg_transaction_value
    FROM ext_daily_sales_summary  d
    JOIN ext_product_performance  p ON d.product = p.product
    ');
    PRINT 'vw_sales_dashboard created';
END
ELSE
    PRINT 'vw_sales_dashboard already exists — skipping';
GO

-- ── Step 9: Verify everything ──────────────────────────────
SELECT 'external_file_formats' AS object_type, name FROM sys.external_file_formats
UNION ALL
SELECT 'external_data_sources', name FROM sys.external_data_sources
UNION ALL
SELECT 'external_tables',       name FROM sys.external_tables
UNION ALL
SELECT 'views',                 name FROM sys.views WHERE is_ms_shipped = 0
ORDER BY object_type, name;
GO
