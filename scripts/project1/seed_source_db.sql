-- ============================================================
-- seed_source_db.sql
-- Seeds the FinCore source operational database
-- Run against: sqlsvr-delearn-dev.database.windows.net
-- Database: sqldb-fincore-source
-- ============================================================

USE sqldb-fincore-source;
GO

-- ── Drop tables if rerunning ───────────────────────────────
IF OBJECT_ID('dbo.fact_transactions', 'U') IS NOT NULL DROP TABLE dbo.fact_transactions;
IF OBJECT_ID('dbo.dim_accounts',      'U') IS NOT NULL DROP TABLE dbo.dim_accounts;
IF OBJECT_ID('dbo.dim_customers',     'U') IS NOT NULL DROP TABLE dbo.dim_customers;
IF OBJECT_ID('dbo.dim_instruments',   'U') IS NOT NULL DROP TABLE dbo.dim_instruments;
GO

-- ── dim_instruments ────────────────────────────────────────
CREATE TABLE dbo.dim_instruments (
    instrument_id   VARCHAR(10)     NOT NULL PRIMARY KEY,
    ticker          VARCHAR(10)     NOT NULL,
    instrument_name VARCHAR(100)    NOT NULL,
    asset_class     VARCHAR(50)     NOT NULL,  -- EQUITY, BOND, ETF, COMMODITY
    sector          VARCHAR(50)     NULL,
    currency        VARCHAR(3)      NOT NULL,
    exchange        VARCHAR(20)     NOT NULL,
    is_active       BIT             NOT NULL DEFAULT 1,
    created_at      DATETIME2       NOT NULL DEFAULT GETUTCDATE(),
    updated_at      DATETIME2       NOT NULL DEFAULT GETUTCDATE()
);

INSERT INTO dbo.dim_instruments
    (instrument_id, ticker, instrument_name, asset_class, sector, currency, exchange)
VALUES
    ('INST001', 'AAPL',  'Apple Inc',                    'EQUITY',    'Technology',    'USD', 'NASDAQ'),
    ('INST002', 'MSFT',  'Microsoft Corporation',        'EQUITY',    'Technology',    'USD', 'NASDAQ'),
    ('INST003', 'GOOGL', 'Alphabet Inc',                 'EQUITY',    'Technology',    'USD', 'NASDAQ'),
    ('INST004', 'JPM',   'JPMorgan Chase',               'EQUITY',    'Financials',    'USD', 'NYSE'),
    ('INST005', 'GS',    'Goldman Sachs Group',          'EQUITY',    'Financials',    'USD', 'NYSE'),
    ('INST006', 'BRK',   'Berkshire Hathaway',           'EQUITY',    'Financials',    'USD', 'NYSE'),
    ('INST007', 'SPY',   'SPDR S&P 500 ETF Trust',       'ETF',       NULL,            'USD', 'NYSE'),
    ('INST008', 'QQQ',   'Invesco QQQ Trust',            'ETF',       NULL,            'USD', 'NASDAQ'),
    ('INST009', 'GLD',   'SPDR Gold Shares',             'COMMODITY', NULL,            'USD', 'NYSE'),
    ('INST010', 'TLT',   'iShares 20+ Year Treasury',    'BOND',      'Government',    'USD', 'NASDAQ');
GO

-- ── dim_customers ──────────────────────────────────────────
CREATE TABLE dbo.dim_customers (
    customer_id         VARCHAR(10)     NOT NULL PRIMARY KEY,
    first_name          VARCHAR(50)     NOT NULL,
    last_name           VARCHAR(50)     NOT NULL,
    email               VARCHAR(100)    NOT NULL,
    country             VARCHAR(50)     NOT NULL,
    city                VARCHAR(50)     NULL,
    customer_segment    VARCHAR(20)     NOT NULL,  -- RETAIL, HNI, INSTITUTIONAL
    risk_rating         VARCHAR(10)     NOT NULL,  -- LOW, MEDIUM, HIGH
    kyc_status          VARCHAR(20)     NOT NULL,  -- VERIFIED, PENDING, REJECTED
    relationship_manager VARCHAR(50)   NULL,
    onboard_date        DATE            NOT NULL,
    is_active           BIT             NOT NULL DEFAULT 1,
    created_at          DATETIME2       NOT NULL DEFAULT GETUTCDATE(),
    updated_at          DATETIME2       NOT NULL DEFAULT GETUTCDATE()
);

INSERT INTO dbo.dim_customers
    (customer_id, first_name, last_name, email, country, city,
     customer_segment, risk_rating, kyc_status, relationship_manager, onboard_date)
VALUES
    ('CUST001', 'Rajesh',   'Mehta',      'rajesh.mehta@email.com',    'India',   'Mumbai',    'HNI',         'HIGH',   'VERIFIED', 'Sarah Connor',  '2020-01-15'),
    ('CUST002', 'Emily',    'Chen',       'emily.chen@email.com',      'USA',     'New York',  'INSTITUTIONAL','LOW',    'VERIFIED', 'John Smith',    '2019-06-01'),
    ('CUST003', 'Mohammed', 'Al-Farsi',   'mohammed.af@email.com',     'UAE',     'Dubai',     'HNI',         'MEDIUM', 'VERIFIED', 'Sarah Connor',  '2021-03-22'),
    ('CUST004', 'Sophie',   'Dubois',     'sophie.dubois@email.com',   'France',  'Paris',     'RETAIL',      'LOW',    'VERIFIED', NULL,            '2022-07-10'),
    ('CUST005', 'James',    'Okafor',     'james.okafor@email.com',    'Nigeria', 'Lagos',     'RETAIL',      'MEDIUM', 'VERIFIED', NULL,            '2022-11-05'),
    ('CUST006', 'Priya',    'Sharma',     'priya.sharma@email.com',    'India',   'Bangalore', 'HNI',         'LOW',    'VERIFIED', 'John Smith',    '2020-09-18'),
    ('CUST007', 'Carlos',   'Rodriguez',  'carlos.rod@email.com',      'Mexico',  'Mexico City','RETAIL',     'MEDIUM', 'PENDING',  NULL,            '2023-02-14'),
    ('CUST008', 'Mei',      'Zhang',      'mei.zhang@email.com',       'China',   'Shanghai',  'INSTITUTIONAL','LOW',   'VERIFIED', 'Sarah Connor',  '2018-12-01'),
    ('CUST009', 'Ahmed',    'Hassan',     'ahmed.hassan@email.com',    'Egypt',   'Cairo',     'RETAIL',      'HIGH',   'VERIFIED', NULL,            '2023-05-30'),
    ('CUST010', 'Anna',     'Kowalski',   'anna.kowalski@email.com',   'Poland',  'Warsaw',    'RETAIL',      'LOW',    'VERIFIED', NULL,            '2021-08-12');
GO

-- ── dim_accounts ───────────────────────────────────────────
CREATE TABLE dbo.dim_accounts (
    account_id      VARCHAR(10)     NOT NULL PRIMARY KEY,
    customer_id     VARCHAR(10)     NOT NULL REFERENCES dbo.dim_customers(customer_id),
    account_type    VARCHAR(20)     NOT NULL,  -- TRADING, SAVINGS, RETIREMENT, MARGIN
    account_name    VARCHAR(100)    NOT NULL,
    currency        VARCHAR(3)      NOT NULL,
    open_date       DATE            NOT NULL,
    close_date      DATE            NULL,
    status          VARCHAR(20)     NOT NULL,  -- ACTIVE, SUSPENDED, CLOSED
    credit_limit    DECIMAL(18,2)   NULL,
    created_at      DATETIME2       NOT NULL DEFAULT GETUTCDATE(),
    updated_at      DATETIME2       NOT NULL DEFAULT GETUTCDATE()
);

INSERT INTO dbo.dim_accounts
    (account_id, customer_id, account_type, account_name, currency, open_date, status, credit_limit)
VALUES
    ('ACC001', 'CUST001', 'TRADING',    'Rajesh Primary Trading',      'USD', '2020-01-15', 'ACTIVE',    NULL),
    ('ACC002', 'CUST001', 'MARGIN',     'Rajesh Margin Account',       'USD', '2020-03-01', 'ACTIVE',    500000.00),
    ('ACC003', 'CUST002', 'TRADING',    'Emily Institutional',         'USD', '2019-06-01', 'ACTIVE',    NULL),
    ('ACC004', 'CUST003', 'TRADING',    'Mohammed Trading',            'USD', '2021-03-22', 'ACTIVE',    NULL),
    ('ACC005', 'CUST003', 'RETIREMENT', 'Mohammed Retirement Fund',    'USD', '2021-04-01', 'ACTIVE',    NULL),
    ('ACC006', 'CUST004', 'SAVINGS',    'Sophie Savings',              'EUR', '2022-07-10', 'ACTIVE',    NULL),
    ('ACC007', 'CUST005', 'TRADING',    'James Trading',               'USD', '2022-11-05', 'ACTIVE',    NULL),
    ('ACC008', 'CUST006', 'TRADING',    'Priya Primary',               'USD', '2020-09-18', 'ACTIVE',    NULL),
    ('ACC009', 'CUST007', 'TRADING',    'Carlos Trading',              'USD', '2023-02-14', 'SUSPENDED', NULL),
    ('ACC010', 'CUST008', 'TRADING',    'Mei Institutional Portfolio', 'USD', '2018-12-01', 'ACTIVE',    NULL),
    ('ACC011', 'CUST009', 'TRADING',    'Ahmed Trading',               'USD', '2023-05-30', 'ACTIVE',    NULL),
    ('ACC012', 'CUST010', 'SAVINGS',    'Anna Savings',                'EUR', '2021-08-12', 'ACTIVE',    NULL);
GO

-- ── fact_transactions ──────────────────────────────────────
CREATE TABLE dbo.fact_transactions (
    transaction_id  VARCHAR(15)     NOT NULL PRIMARY KEY,
    account_id      VARCHAR(10)     NOT NULL REFERENCES dbo.dim_accounts(account_id),
    instrument_id   VARCHAR(10)     NOT NULL REFERENCES dbo.dim_instruments(instrument_id),
    transaction_date DATE           NOT NULL,
    transaction_type VARCHAR(10)    NOT NULL,  -- BUY, SELL, DIVIDEND, FEE
    quantity        DECIMAL(18,6)   NOT NULL,
    price           DECIMAL(18,4)   NOT NULL,
    gross_amount    DECIMAL(18,2)   NOT NULL,
    fees            DECIMAL(18,2)   NOT NULL DEFAULT 0,
    net_amount      DECIMAL(18,2)   NOT NULL,
    currency        VARCHAR(3)      NOT NULL,
    settlement_date DATE            NULL,
    status          VARCHAR(20)     NOT NULL,  -- SETTLED, PENDING, FAILED, CANCELLED
    notes           VARCHAR(200)    NULL,
    created_at      DATETIME2       NOT NULL DEFAULT GETUTCDATE()
);

INSERT INTO dbo.fact_transactions
    (transaction_id, account_id, instrument_id, transaction_date,
     transaction_type, quantity, price, gross_amount, fees, net_amount,
     currency, settlement_date, status)
VALUES
    ('TXN20240101001', 'ACC001', 'INST001', '2024-01-02', 'BUY',  100.000000, 185.2000, 18520.00, 9.99, 18529.99, 'USD', '2024-01-04', 'SETTLED'),
    ('TXN20240101002', 'ACC001', 'INST002', '2024-01-02', 'BUY',  50.000000,  374.1000, 18705.00, 9.99, 18714.99, 'USD', '2024-01-04', 'SETTLED'),
    ('TXN20240101003', 'ACC003', 'INST007', '2024-01-03', 'BUY',  200.000000, 476.3000, 95260.00, 0.00, 95260.00, 'USD', '2024-01-05', 'SETTLED'),
    ('TXN20240101004', 'ACC004', 'INST001', '2024-01-05', 'BUY',  75.000000,  187.6800, 14076.00, 9.99, 14085.99, 'USD', '2024-01-09', 'SETTLED'),
    ('TXN20240101005', 'ACC008', 'INST003', '2024-01-08', 'BUY',  25.000000,  140.9300, 3523.25,  9.99,  3533.24, 'USD', '2024-01-10', 'SETTLED'),
    ('TXN20240101006', 'ACC002', 'INST005', '2024-01-10', 'BUY',  30.000000,  382.5000, 11475.00, 9.99, 11484.99, 'USD', '2024-01-12', 'SETTLED'),
    ('TXN20240101007', 'ACC010', 'INST008', '2024-01-12', 'BUY',  500.000000, 400.2000,200100.00, 0.00,200100.00, 'USD', '2024-01-16', 'SETTLED'),
    ('TXN20240101008', 'ACC001', 'INST001', '2024-01-15', 'SELL', 50.000000,  191.5500,  9577.50, 9.99,  9567.51, 'USD', '2024-01-17', 'SETTLED'),
    ('TXN20240101009', 'ACC007', 'INST009', '2024-01-18', 'BUY',  40.000000,  183.4000,  7336.00, 9.99,  7345.99, 'USD', '2024-01-22', 'SETTLED'),
    ('TXN20240101010', 'ACC011', 'INST004', '2024-01-20', 'BUY',  60.000000,  168.7500, 10125.00, 9.99, 10134.99, 'USD', '2024-01-24', 'SETTLED'),
    ('TXN20240201001', 'ACC001', 'INST002', '2024-02-01', 'BUY',  25.000000,  404.5000, 10112.50, 9.99, 10122.49, 'USD', '2024-02-05', 'SETTLED'),
    ('TXN20240201002', 'ACC003', 'INST010', '2024-02-05', 'BUY',  1000.000000, 96.3000, 96300.00, 0.00, 96300.00, 'USD', '2024-02-07', 'SETTLED'),
    ('TXN20240201003', 'ACC004', 'INST007', '2024-02-08', 'BUY',  100.000000, 488.1000, 48810.00, 9.99, 48819.99, 'USD', '2024-02-12', 'SETTLED'),
    ('TXN20240201004', 'ACC008', 'INST001', '2024-02-12', 'BUY',  80.000000,  184.3700, 14749.60, 9.99, 14759.59, 'USD', '2024-02-14', 'SETTLED'),
    ('TXN20240201005', 'ACC010', 'INST003', '2024-02-15', 'SELL', 100.000000, 152.1000, 15210.00, 0.00, 15210.00, 'USD', '2024-02-19', 'SETTLED'),
    ('TXN20240301001', 'ACC005', 'INST010', '2024-03-01', 'BUY',  500.000000,  94.7500, 47375.00, 0.00, 47375.00, 'USD', '2024-03-05', 'SETTLED'),
    ('TXN20240301002', 'ACC001', 'INST009', '2024-03-05', 'BUY',  20.000000,  179.8000,  3596.00, 9.99,  3605.99, 'USD', '2024-03-07', 'SETTLED'),
    ('TXN20240301003', 'ACC002', 'INST005', '2024-03-10', 'SELL', 15.000000,  395.6000,  5934.00, 9.99,  5924.01, 'USD', '2024-03-12', 'SETTLED'),
    ('TXN20240301004', 'ACC007', 'INST004', '2024-03-15', 'BUY',  45.000000,  196.2000,  8829.00, 9.99,  8838.99, 'USD', '2024-03-19', 'SETTLED'),
    ('TXN20240301005', 'ACC011', 'INST002', '2024-03-20', 'BUY',  35.000000,  420.5500, 14719.25, 9.99, 14729.24, 'USD', '2024-03-22', 'SETTLED');
GO

-- ── Verify ─────────────────────────────────────────────────
SELECT 'dim_instruments'  AS table_name, COUNT(*) AS row_count FROM dbo.dim_instruments
UNION ALL
SELECT 'dim_customers',   COUNT(*) FROM dbo.dim_customers
UNION ALL
SELECT 'dim_accounts',    COUNT(*) FROM dbo.dim_accounts
UNION ALL
SELECT 'fact_transactions', COUNT(*) FROM dbo.fact_transactions;
GO