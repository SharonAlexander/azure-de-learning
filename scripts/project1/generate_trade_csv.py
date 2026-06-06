"""
generate_trade_csv.py
Generates trade record CSV files and uploads them to ADLS raw/fincore/trades/
Simulates the flat file drop pattern from a trading desk system.

Usage:
    python scripts/project1/generate_trade_csv.py \
        --storage-account sadelearnnew0001 \
        --months 3

Requirements:
    pip install azure-storage-file-datalake azure-identity
"""

import argparse
import csv
import io
import random
from datetime import date, timedelta
from typing import List, Dict

from azure.identity import DefaultAzureCredential
from azure.storage.filedatalake import DataLakeServiceClient


# ── Config ────────────────────────────────────────────────────────────────────

ACCOUNTS = [
    "ACC001", "ACC002", "ACC003", "ACC004",
    "ACC005", "ACC007", "ACC008", "ACC010", "ACC011"
]

INSTRUMENTS = [
    "INST001", "INST002", "INST003", "INST004", "INST005",
    "INST006", "INST007", "INST008", "INST009", "INST010"
]

BASE_PRICES = {
    "INST001": 185.00, "INST002": 374.00, "INST003": 140.00,
    "INST004": 168.00, "INST005": 382.00, "INST006": 355.00,
    "INST007": 476.00, "INST008": 400.00, "INST009": 183.00,
    "INST010":  96.00,
}

BROKERS = ["Goldman Sachs", "JP Morgan", "Morgan Stanley", "CLSA", "Citi"]


# ── Generators ────────────────────────────────────────────────────────────────

def generate_trades_for_month(year: int, month: int) -> List[Dict]:
    """Generate 15-25 trade records for a given month"""
    random.seed(year * 100 + month)  # deterministic per month

    # Work out first and last business day of the month
    first_day = date(year, month, 1)
    if month == 12:
        last_day = date(year + 1, 1, 1) - timedelta(days=1)
    else:
        last_day = date(year, month + 1, 1) - timedelta(days=1)

    # Collect business days
    business_days = []
    current = first_day
    while current <= last_day:
        if current.weekday() < 5:   # Monday–Friday only
            business_days.append(current)
        current += timedelta(days=1)

    trades      = []
    trade_count = random.randint(15, 25)
    trade_seq   = 1

    for _ in range(trade_count):
        trade_date    = random.choice(business_days)
        instrument_id = random.choice(INSTRUMENTS)
        account_id    = random.choice(ACCOUNTS)
        side          = random.choice(["BUY", "SELL"])
        base_price    = BASE_PRICES[instrument_id]
        quantity      = random.choice([10, 25, 50, 75, 100, 150, 200, 250, 500])

        # Executed price: within ±0.5% of base
        slippage       = random.uniform(-0.005, 0.005)
        executed_price = round(base_price * (1 + slippage), 4)
        gross_amount   = round(quantity * executed_price, 2)

        # Brokerage: 0.05% for large trades, flat $9.99 for small
        fees           = 0.00 if gross_amount > 50000 else 9.99

        # Settlement: T+2
        settlement     = trade_date + timedelta(days=2)
        while settlement.weekday() >= 5:
            settlement += timedelta(days=1)

        trade_id = f"TRD{year}{month:02d}{trade_seq:04d}"
        trade_seq += 1

        trades.append({
            "trade_id":         trade_id,
            "account_id":       account_id,
            "instrument_id":    instrument_id,
            "trade_date":       trade_date.isoformat(),
            "side":             side,
            "quantity":         quantity,
            "executed_price":   executed_price,
            "gross_amount":     gross_amount,
            "fees":             fees,
            "net_amount":       round(gross_amount + fees, 2) if side == "BUY" else round(gross_amount - fees, 2),
            "currency":         "USD",
            "settlement_date":  settlement.isoformat(),
            "broker":           random.choice(BROKERS),
            "order_type":       random.choice(["MARKET", "LIMIT", "LIMIT"]),
            "status":           "SETTLED",
            "source_system":    "trading_desk_export",
        })

    return sorted(trades, key=lambda x: x["trade_date"])


def trades_to_csv_bytes(trades: List[Dict]) -> bytes:
    """Convert list of trade dicts to CSV bytes"""
    if not trades:
        return b""

    output    = io.StringIO()
    fieldnames = list(trades[0].keys())
    writer    = csv.DictWriter(output, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(trades)
    return output.getvalue().encode("utf-8")


def upload_to_adls(
    storage_account: str,
    container:       str,
    path:            str,
    data:            bytes
) -> None:
    """Upload bytes to ADLS Gen2 using DefaultAzureCredential (Azure CLI login)"""
    credential = DefaultAzureCredential()
    service    = DataLakeServiceClient(
        account_url=f"https://{storage_account}.dfs.core.windows.net",
        credential=credential
    )
    fs     = service.get_file_system_client(container)
    client = fs.get_file_client(path)

    client.upload_data(data, overwrite=True)
    print(f"    ✓ Uploaded: {path} ({len(data):,} bytes)")


# ── Main ──────────────────────────────────────────────────────────────────────

def parse_args():
    p = argparse.ArgumentParser(description="Generate FinCore trade CSV files")
    p.add_argument("--storage-account", required=True,
                   help="ADLS Gen2 storage account name")
    p.add_argument("--months",          type=int, default=3,
                   help="Number of months to generate (default: 3)")
    p.add_argument("--start-year",      type=int, default=2024,
                   help="Starting year (default: 2024)")
    p.add_argument("--start-month",     type=int, default=1,
                   help="Starting month (default: 1)")
    p.add_argument("--container",       default="medallion",
                   help="ADLS container name (default: medallion)")
    return p.parse_args()


def main():
    args = parse_args()

    print("=" * 55)
    print("  FinCore Trade CSV Generator")
    print(f"  Storage:  {args.storage_account}")
    print(f"  Months:   {args.months} (from {args.start_year}-{args.start_month:02d})")
    print("=" * 55)

    year  = args.start_year
    month = args.start_month

    total_trades = 0

    for i in range(args.months):
        print(f"\n[{i+1}/{args.months}] Generating trades for {year}-{month:02d}")

        trades    = generate_trades_for_month(year, month)
        csv_bytes = trades_to_csv_bytes(trades)

        # Path: raw/fincore/trades/YYYY/MM/trades_YYYYMM.csv
        adls_path = f"raw/fincore/trades/{year}/{month:02d}/trades_{year}{month:02d}.csv"

        upload_to_adls(
            storage_account=args.storage_account,
            container=args.container,
            path=adls_path,
            data=csv_bytes
        )

        total_trades += len(trades)
        print(f"    Records: {len(trades)}")

        # Advance to next month
        if month == 12:
            month = 1
            year += 1
        else:
            month += 1

    print(f"\n{'='*55}")
    print(f"  ✓ Done — {total_trades} trade records uploaded")
    print(f"  Path: raw/fincore/trades/")
    print(f"{'='*55}")


if __name__ == "__main__":
    main()