"""
api_simulator.py
Simulates a financial market data REST API for FinCore Analytics.
Serves market prices and portfolio valuations.

Run with: python scripts/project1/api_simulator.py
Endpoints:
    GET /api/v1/health
    GET /api/v1/market-prices?date=YYYY-MM-DD
    GET /api/v1/market-prices/latest
    GET /api/v1/portfolios?account_id=ACCXXX
    GET /api/v1/portfolios/all

ADF calls these endpoints via the Self-hosted IR.
"""

import json
import random
from datetime import date, datetime, timedelta
from flask import Flask, jsonify, request

app = Flask(__name__)

# ── Seed data ────────────────────────────────────────────────────────────────

# Base prices per instrument — realistic starting points
BASE_PRICES = {
    "INST001": {"ticker": "AAPL",  "base": 185.00},
    "INST002": {"ticker": "MSFT",  "base": 374.00},
    "INST003": {"ticker": "GOOGL", "base": 140.00},
    "INST004": {"ticker": "JPM",   "base": 168.00},
    "INST005": {"ticker": "GS",    "base": 382.00},
    "INST006": {"ticker": "BRK",   "base": 355.00},
    "INST007": {"ticker": "SPY",   "base": 476.00},
    "INST008": {"ticker": "QQQ",   "base": 400.00},
    "INST009": {"ticker": "GLD",   "base": 183.00},
    "INST010": {"ticker": "TLT",   "base":  96.00},
}

# Account holdings — what each account holds and how many shares
ACCOUNT_HOLDINGS = {
    "ACC001": [
        {"instrument_id": "INST001", "quantity": 50,   "avg_cost": 185.20},
        {"instrument_id": "INST002", "quantity": 50,   "avg_cost": 374.10},
        {"instrument_id": "INST009", "quantity": 20,   "avg_cost": 179.80},
    ],
    "ACC002": [
        {"instrument_id": "INST005", "quantity": 15,   "avg_cost": 382.50},
    ],
    "ACC003": [
        {"instrument_id": "INST007", "quantity": 200,  "avg_cost": 476.30},
        {"instrument_id": "INST010", "quantity": 1000, "avg_cost":  96.30},
    ],
    "ACC004": [
        {"instrument_id": "INST001", "quantity": 75,   "avg_cost": 187.68},
        {"instrument_id": "INST007", "quantity": 100,  "avg_cost": 488.10},
    ],
    "ACC005": [
        {"instrument_id": "INST010", "quantity": 1500, "avg_cost":  95.10},
    ],
    "ACC007": [
        {"instrument_id": "INST009", "quantity": 40,   "avg_cost": 183.40},
        {"instrument_id": "INST004", "quantity": 45,   "avg_cost": 196.20},
    ],
    "ACC008": [
        {"instrument_id": "INST003", "quantity": 25,   "avg_cost": 140.93},
        {"instrument_id": "INST001", "quantity": 80,   "avg_cost": 184.37},
    ],
    "ACC010": [
        {"instrument_id": "INST008", "quantity": 500,  "avg_cost": 400.20},
        {"instrument_id": "INST003", "quantity": 0,    "avg_cost": 152.10},  # sold
    ],
    "ACC011": [
        {"instrument_id": "INST004", "quantity": 60,   "avg_cost": 168.75},
        {"instrument_id": "INST002", "quantity": 35,   "avg_cost": 420.55},
    ],
}


def generate_daily_price(instrument_id: str, price_date: date) -> dict:
    """
    Generate a realistic OHLCV price for an instrument on a given date.
    Uses the base price with a deterministic seed so same date = same price.
    """
    if instrument_id not in BASE_PRICES:
        return None

    info = BASE_PRICES[instrument_id]

    # Deterministic variation based on date + instrument
    # so the same request always returns the same price
    seed_val = int(price_date.strftime("%Y%m%d")) + hash(instrument_id) % 1000
    random.seed(seed_val)

    # Daily drift: ±2% from base
    drift    = 1 + random.uniform(-0.02, 0.02)
    close    = round(info["base"] * drift, 4)
    open_    = round(close * (1 + random.uniform(-0.005, 0.005)), 4)
    high     = round(max(open_, close) * (1 + random.uniform(0, 0.01)), 4)
    low      = round(min(open_, close) * (1 - random.uniform(0, 0.01)), 4)
    volume   = random.randint(1_000_000, 50_000_000)

    return {
        "price_id":      f"PRC{price_date.strftime('%Y%m%d')}{instrument_id}",
        "instrument_id": instrument_id,
        "ticker":        info["ticker"],
        "price_date":    price_date.isoformat(),
        "open_price":    open_,
        "high_price":    high,
        "low_price":     low,
        "close_price":   close,
        "volume":        volume,
        "currency":      "USD",
        "source":        "fincore_market_feed",
        "captured_at":   datetime.utcnow().isoformat() + "Z"
    }


def calculate_portfolio(account_id: str, price_date: date) -> dict:
    """Calculate portfolio valuation for an account on a given date."""
    if account_id not in ACCOUNT_HOLDINGS:
        return None

    holdings     = ACCOUNT_HOLDINGS[account_id]
    positions    = []
    total_value  = 0.0
    total_cost   = 0.0

    for holding in holdings:
        if holding["quantity"] <= 0:
            continue

        instrument_id = holding["instrument_id"]
        price_data    = generate_daily_price(instrument_id, price_date)
        if not price_data:
            continue

        market_value   = round(holding["quantity"] * price_data["close_price"], 2)
        cost_basis     = round(holding["quantity"] * holding["avg_cost"], 2)
        unrealised_pnl = round(market_value - cost_basis, 2)
        pnl_pct        = round((unrealised_pnl / cost_basis) * 100, 4) if cost_basis != 0 else 0

        positions.append({
            "instrument_id":   instrument_id,
            "ticker":          BASE_PRICES[instrument_id]["ticker"],
            "quantity":        holding["quantity"],
            "avg_cost":        holding["avg_cost"],
            "current_price":   price_data["close_price"],
            "market_value":    market_value,
            "cost_basis":      cost_basis,
            "unrealised_pnl":  unrealised_pnl,
            "pnl_pct":         pnl_pct,
        })

        total_value += market_value
        total_cost  += cost_basis

    total_pnl     = round(total_value - total_cost, 2)
    total_pnl_pct = round((total_pnl / total_cost) * 100, 4) if total_cost != 0 else 0

    return {
        "valuation_id":   f"VAL{price_date.strftime('%Y%m%d')}{account_id}",
        "account_id":     account_id,
        "valuation_date": price_date.isoformat(),
        "total_value":    round(total_value, 2),
        "total_cost":     round(total_cost, 2),
        "total_pnl":      total_pnl,
        "total_pnl_pct":  total_pnl_pct,
        "position_count": len(positions),
        "positions":      positions,
        "currency":       "USD",
        "captured_at":    datetime.utcnow().isoformat() + "Z"
    }


# ── Endpoints ────────────────────────────────────────────────────────────────

@app.route("/api/v1/health", methods=["GET"])
def health():
    """Health check endpoint"""
    return jsonify({
        "status":    "healthy",
        "service":   "FinCore Market Data API",
        "version":   "1.0.0",
        "timestamp": datetime.utcnow().isoformat() + "Z"
    }), 200


@app.route("/api/v1/market-prices", methods=["GET"])
def get_market_prices():
    """
    Get market prices for all instruments on a specific date.
    Query param: date (YYYY-MM-DD) — defaults to yesterday if not provided
    ADF calls this with ?date=@pipeline().parameters.load_date
    """
    date_str = request.args.get("date")

    if date_str:
        try:
            price_date = date.fromisoformat(date_str)
        except ValueError:
            return jsonify({
                "error":   "Invalid date format",
                "message": "Use YYYY-MM-DD format"
            }), 400
    else:
        price_date = date.today() - timedelta(days=1)

    prices = []
    for instrument_id in BASE_PRICES:
        price = generate_daily_price(instrument_id, price_date)
        if price:
            prices.append(price)

    return jsonify({
        "date":        price_date.isoformat(),
        "count":       len(prices),
        "prices":      prices,
        "captured_at": datetime.utcnow().isoformat() + "Z"
    }), 200


@app.route("/api/v1/market-prices/latest", methods=["GET"])
def get_latest_prices():
    """
    Get latest market prices — uses today's date.
    No parameters required.
    """
    price_date = date.today()
    prices = []
    for instrument_id in BASE_PRICES:
        price = generate_daily_price(instrument_id, price_date)
        if price:
            prices.append(price)

    return jsonify({
        "date":        price_date.isoformat(),
        "count":       len(prices),
        "prices":      prices,
        "captured_at": datetime.utcnow().isoformat() + "Z"
    }), 200


@app.route("/api/v1/portfolios", methods=["GET"])
def get_portfolio():
    """
    Get portfolio valuation for a specific account.
    Query params:
        account_id (required)
        date (YYYY-MM-DD, optional — defaults to yesterday)
    """
    account_id = request.args.get("account_id")
    date_str   = request.args.get("date")

    if not account_id:
        return jsonify({
            "error":   "Missing parameter",
            "message": "account_id is required"
        }), 400

    if date_str:
        try:
            price_date = date.fromisoformat(date_str)
        except ValueError:
            return jsonify({
                "error":   "Invalid date format",
                "message": "Use YYYY-MM-DD format"
            }), 400
    else:
        price_date = date.today() - timedelta(days=1)

    portfolio = calculate_portfolio(account_id, price_date)

    if not portfolio:
        return jsonify({
            "error":   "Account not found",
            "message": f"No portfolio data for account {account_id}"
        }), 404

    return jsonify(portfolio), 200


@app.route("/api/v1/portfolios/all", methods=["GET"])
def get_all_portfolios():
    """
    Get portfolio valuations for all accounts on a specific date.
    Query param: date (YYYY-MM-DD) — defaults to yesterday
    ADF calls this endpoint for bulk portfolio ingestion.
    """
    date_str = request.args.get("date")

    if date_str:
        try:
            price_date = date.fromisoformat(date_str)
        except ValueError:
            return jsonify({
                "error":   "Invalid date format",
                "message": "Use YYYY-MM-DD format"
            }), 400
    else:
        price_date = date.today() - timedelta(days=1)

    portfolios = []
    for account_id in ACCOUNT_HOLDINGS:
        portfolio = calculate_portfolio(account_id, price_date)
        if portfolio:
            # Flatten for ADF ingestion — no nested positions in this endpoint
            portfolios.append({
                "valuation_id":   portfolio["valuation_id"],
                "account_id":     portfolio["account_id"],
                "valuation_date": portfolio["valuation_date"],
                "total_value":    portfolio["total_value"],
                "total_cost":     portfolio["total_cost"],
                "total_pnl":      portfolio["total_pnl"],
                "total_pnl_pct":  portfolio["total_pnl_pct"],
                "position_count": portfolio["position_count"],
                "currency":       portfolio["currency"],
                "captured_at":    portfolio["captured_at"]
            })

    return jsonify({
        "date":       price_date.isoformat(),
        "count":      len(portfolios),
        "portfolios": portfolios,
        "captured_at": datetime.utcnow().isoformat() + "Z"
    }), 200


# ── Entry point ──────────────────────────────────────────────────────────────

if __name__ == "__main__":
    print("=" * 50)
    print("  FinCore Market Data API Simulator")
    print("  Running on http://localhost:5000")
    print("")
    print("  Endpoints:")
    print("  GET /api/v1/health")
    print("  GET /api/v1/market-prices?date=2024-01-02")
    print("  GET /api/v1/market-prices/latest")
    print("  GET /api/v1/portfolios?account_id=ACC001&date=2024-01-02")
    print("  GET /api/v1/portfolios/all?date=2024-01-02")
    print("=" * 50)
    app.run(host="0.0.0.0", port=5000, debug=False)