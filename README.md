# TradingMonitor

Real-time monitoring dashboard for MetaTrader 5 trading strategies. Receives live telemetry from an MT5 Expert Advisor over TCP, persists it in TimescaleDB, and exposes a FastAPI web dashboard with WebSocket updates and a Typer CLI.

---

## Features

- **Live MT5 Ingestion** — TCP server receives deals, equity updates, account snapshots, and runtime state from a custom MQL5 EA
- **TimescaleDB Storage** — hypertables for high-frequency time-series data (deals, equity curves)
- **Web Dashboard** — FastAPI + Jinja2 with real-time WebSocket updates; pages for overview, strategies, portfolios, backtests, benchmarks, correlation, and settings
- **Performance Analytics** — Sharpe, Sortino, Calmar, Max Drawdown, CVaR, Win Rate, Profit Factor, and more via a plugin-based metrics engine
- **QuantStats Reports** — generate HTML tearsheets for strategies and portfolios; send to Telegram
- **Benchmark Tracking** — sync market benchmarks from DataManager, compare against strategy performance
- **Performance Drift Detection** — alert when live results deviate from backtest expectations (win rate, PF, drawdown)
- **Backtest Storage** — import and store backtest runs alongside live data for side-by-side analysis
- **Telegram Notifications** — operational alerts for margin, VaR thresholds, and drift events
- **CLI** — full Typer CLI for setup, entity registration, reports, and dashboard startup

---

## Requirements

- Python 3.12+
- [uv](https://docs.astral.sh/uv/)
- Docker & Docker Compose (for TimescaleDB)
- MetaTrader 5 terminal (as data source)
- Optional: [DataManager](https://github.com/guilsmatos1/DataManager) running locally for benchmark sync

---

## Installation & Setup

**1. Install dependencies:**
```bash
uv sync
```

**2. Configure environment** — create a `.env` file at the project root:
```env
DATABASE_URL=postgresql://postgres:password@localhost:5433/tradingmonitor
API_KEY=your-secret-key-here

# TCP Ingestion
SERVER_HOST=0.0.0.0
SERVER_PORT=5555

# Dashboard
DASHBOARD_HOST=127.0.0.1
DASHBOARD_PORT=8000

# DataManager integration (optional)
DATAMANAGER_URL=http://127.0.0.1:8686
DATAMANAGER_API_KEY=your-datamanager-key

# Telegram notifications (optional)
ENABLE_NOTIFICATIONS=false
TELEGRAM_TOKEN=
TELEGRAM_CHAT_ID=
```

**3. Start TimescaleDB:**
```bash
docker compose up -d
```

**4. Initialize database schema and hypertables:**
```bash
uv run trading-monitor setup-db
```

**5. Start the dashboard (includes MT5 ingestion by default):**
```bash
uv run trading-monitor start-dashboard
```

Open http://127.0.0.1:8000 in your browser and log in with your `API_KEY`.

---

## MT5 Expert Advisor

Compile `mt5/MetricsPublisher.mq5` inside your MT5 terminal (place it under `MQL5/Experts/`) and attach it to a chart. The EA will push events to the TCP ingestion server.

**Supported message topics:**

| Topic | Description |
|---|---|
| `DEAL` | Closed trade deal |
| `EQUITY` | Equity curve snapshot |
| `ACCOUNT` | Account balance / margin update |
| `STRATEGY_RUNTIME` | Open trades and pending orders count |

**Runtime snapshot payload example:**
```
STRATEGY_RUNTIME {"time":1711737600,"magic":123456,"open_profit":48.35,"open_trades_count":2,"pending_orders_count":1}
```

> The `magic` number is the primary identifier for strategies.

---

## CLI Reference

```bash
# Health check — is the ingestion daemon running?
uv run trading-monitor status

# Database
uv run trading-monitor setup-db

# Start ingestion server only (TCP, no dashboard)
uv run trading-monitor start-ingestion

# Start dashboard (includes ingestion by default)
uv run trading-monitor start-dashboard
uv run trading-monitor start-dashboard --no-ingestion          # dashboard only
uv run trading-monitor start-dashboard --host 0.0.0.0 --port 8080

# Entity registration
uv run trading-monitor register-account <mt5_login> --name "My Account" --broker "ICMarkets" --currency USD
uv run trading-monitor list-accounts

uv run trading-monitor register-strategy <magic_number> --name "Breakout H1" --symbol EURUSD --timeframe H1 \
    --style Breakout --duration "Day Trading" --balance 10000 --live
uv run trading-monitor register-strategy <magic_number> --name "Demo Strat" --demo  # mark as demo

uv run trading-monitor create-portfolio --name "Main Portfolio" --balance 50000 --live --real
uv run trading-monitor add-to-portfolio <portfolio_id> <strategy_id>
uv run trading-monitor list-portfolios

# Reports
uv run trading-monitor report <strategy_id>
uv run trading-monitor portfolio-report <portfolio_id>
uv run trading-monitor send-report --strategy-id <strategy_id>      # generates HTML + sends to Telegram
uv run trading-monitor send-report --portfolio-id <portfolio_id>

# Telegram
uv run trading-monitor test-telegram
```

---

## Architecture

```
MT5 EA (MQL5)
    │  TCP/JSON
    ▼
tradingmonitor_ingestion    ← TCP server, payload validation, heartbeat, dead-letter
    │
    ▼
tradingmonitor_storage      ← SQLAlchemy models, repositories, TimescaleDB
    │
    ▼
tradingmonitor_analytics    ← metrics, benchmarks, drift detection, QuantStats
    │
    ├──▶ trading_monitor_dashboard  ← FastAPI + Jinja2 + WebSocket (base)
    └──▶ trading_monitor_cli        ← Typer CLI (base)
```

**Directory layout:**
```
src/trademachine/
├── core/                           # shared logger and metrics utilities
├── mt5/                            # MT5 report parser
├── tradingmonitor_storage/         # ORM models, repositories, config, schemas
│   ├── db/                         # database engine, models, aggregates, filters
│   └── services/                   # settings services (telegram, datamanager, scheduler)
├── tradingmonitor_ingestion/       # TCP ingestion runtime
│   ├── ingestion/                  # tcp_server, processors, cache, schemas
│   └── integrations/               # DataManager client integration
├── tradingmonitor_analytics/       # analytics engine
│   ├── analysis/                   # benchmarks.py, drift.py
│   ├── metrics/                    # calculator, repository, plugins (sharpe, sortino, etc.)
│   └── services/                   # dashboard analysis, history, metrics, overview
├── trading_monitor_dashboard/      # FastAPI web app
│   ├── static/                     # JS (page-*.js, dashboard.js, table-renderer.js)
│   └── templates/                  # Jinja2 HTML pages
└── trading_monitor_cli/            # Typer CLI entry point
```

---

## Database Migrations

```bash
# Apply all pending migrations
uv run alembic upgrade head

# Create a new migration
uv run alembic revision --autogenerate -m "description"

# Check current revision
uv run alembic current
```

---

## Configuration Reference

All settings are read from environment variables or a `.env` file at the project root.

| Variable | Default | Description |
|---|---|---|
| `DATABASE_URL` | — | PostgreSQL connection string (**required**) |
| `API_KEY` | — | Dashboard login key (**required**) |
| `SERVER_HOST` | `127.0.0.1` | TCP ingestion bind host |
| `SERVER_PORT` | `5555` | TCP ingestion port |
| `DASHBOARD_HOST` | `127.0.0.1` | Dashboard bind host |
| `DASHBOARD_PORT` | `8000` | Dashboard port |
| `DATAMANAGER_URL` | `http://127.0.0.1:8686` | DataManager API URL |
| `DATAMANAGER_API_KEY` | — | DataManager API key |
| `DATAMANAGER_TIMEOUT` | `30.0` | Request timeout (seconds) |
| `ENABLE_NOTIFICATIONS` | `false` | Enable Telegram alerts |
| `TELEGRAM_TOKEN` | — | Telegram bot token |
| `TELEGRAM_CHAT_ID` | — | Telegram chat ID |
| `MARGIN_THRESHOLD_PCT` | `20.0` | Margin alert threshold (%) |
| `VAR_95_THRESHOLD` | `5.0` | VaR alert threshold (%) |
| `ENABLE_DRIFT_ALERTS` | `true` | Enable drift detection |
| `DRIFT_WIN_RATE_THRESHOLD` | `15.0` | Max allowed win rate drop (%) |
| `DRIFT_PF_THRESHOLD` | `20.0` | Max allowed profit factor drop (%) |
| `DRIFT_DD_MULTIPLIER` | `1.2` | Max drawdown vs backtest multiplier |
| `DRIFT_MIN_TRADES` | `20` | Minimum trades before drift check |
| `DEBUG` | `false` | Verbose logging |

---

## Testing

```bash
uv run pytest                          # all tests
uv run pytest -m "not integration"     # skip integration tests
uv run pytest test/tradingmonitor_analytics/
uv run pytest test/tradingmonitor_storage/
uv run pytest test/tradingmonitor_ingestion/
```
