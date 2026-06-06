-- Ingestion config for FinCore project
-- This drives the config-driven SQL ingestion pipeline

IF OBJECT_ID('dbo.fincore_ingestion_config', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.fincore_ingestion_config (
        config_id       INT IDENTITY(1,1) PRIMARY KEY,
        source_name     VARCHAR(100)    NOT NULL,
        source_schema   VARCHAR(50)     NOT NULL DEFAULT 'dbo',
        source_table    VARCHAR(100)    NOT NULL,
        target_folder   VARCHAR(500)    NOT NULL,
        load_type       VARCHAR(20)     NOT NULL, -- FULL, INCREMENTAL
        watermark_col   VARCHAR(100)    NULL,      -- for incremental loads
        is_active       BIT             NOT NULL DEFAULT 1,
        created_at      DATETIME2       NOT NULL DEFAULT GETUTCDATE()
    );

    INSERT INTO dbo.fincore_ingestion_config
        (source_name, source_schema, source_table, target_folder, load_type, watermark_col)
    VALUES
        ('dim_instruments',   'dbo', 'dim_instruments',   'raw/fincore/instruments',   'FULL',        NULL),
        ('dim_customers',     'dbo', 'dim_customers',     'raw/fincore/customers',     'FULL',        NULL),
        ('dim_accounts',      'dbo', 'dim_accounts',      'raw/fincore/accounts',      'FULL',        NULL),
        ('fact_transactions', 'dbo', 'fact_transactions', 'raw/fincore/transactions',  'INCREMENTAL', 'created_at');

    PRINT 'fincore_ingestion_config created and seeded';
END
ELSE
    PRINT 'fincore_ingestion_config already exists';
GO

-- Pipeline run log for FinCore (extends existing pipeline_log)
IF OBJECT_ID('dbo.fincore_pipeline_log', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.fincore_pipeline_log (
        log_id          INT IDENTITY(1,1) PRIMARY KEY,
        pipeline_name   VARCHAR(200)    NOT NULL,
        run_id          VARCHAR(200)    NOT NULL,
        source_name     VARCHAR(100)    NOT NULL,
        status          VARCHAR(50)     NOT NULL,
        rows_read       INT             NULL,
        rows_written    INT             NULL,
        error_message   VARCHAR(MAX)    NULL,
        run_start       DATETIME2       NOT NULL,
        run_end         DATETIME2       NULL,
        load_date       DATE            NOT NULL
    );
    PRINT 'fincore_pipeline_log created';
END
GO

-- Watermark table for incremental loads
IF OBJECT_ID('dbo.fincore_watermark', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.fincore_watermark (
        source_name         VARCHAR(100)    NOT NULL PRIMARY KEY,
        last_load_datetime  DATETIME2       NOT NULL DEFAULT '1900-01-01'
    );

    INSERT INTO dbo.fincore_watermark (source_name, last_load_datetime)
    VALUES ('fact_transactions', '1900-01-01');

    PRINT 'fincore_watermark created';
END
GO

-- Stored procedure for logging
IF OBJECT_ID('dbo.usp_log_fincore_pipeline', 'P') IS NULL
BEGIN
    EXEC('
    CREATE PROCEDURE dbo.usp_log_fincore_pipeline
        @pipeline_name  VARCHAR(200),
        @run_id         VARCHAR(200),
        @source_name    VARCHAR(100),
        @status         VARCHAR(50),
        @rows_read      INT,
        @rows_written   INT,
        @error_message  VARCHAR(MAX),
        @run_start      DATETIME2,
        @run_end        DATETIME2,
        @load_date      DATE
    AS
    BEGIN
        INSERT INTO dbo.fincore_pipeline_log
            (pipeline_name, run_id, source_name, status,
             rows_read, rows_written, error_message, run_start, run_end, load_date)
        VALUES
            (@pipeline_name, @run_id, @source_name, @status,
             @rows_read, @rows_written, @error_message, @run_start, @run_end, @load_date)
    END
    ');
    PRINT 'usp_log_fincore_pipeline created';
END
GO

-- Stored procedure to update watermark
IF OBJECT_ID('dbo.usp_update_fincore_watermark', 'P') IS NULL
BEGIN
    EXEC('
    CREATE PROCEDURE dbo.usp_update_fincore_watermark
        @source_name            VARCHAR(100),
        @last_load_datetime     DATETIME2
    AS
    BEGIN
        UPDATE dbo.fincore_watermark
        SET    last_load_datetime = @last_load_datetime
        WHERE  source_name = @source_name
    END
    ');
    PRINT 'usp_update_fincore_watermark created';
END
GO

SELECT * FROM dbo.fincore_ingestion_config;
SELECT * FROM dbo.fincore_watermark;
GO
