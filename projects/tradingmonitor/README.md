# TradingMonitor

A comprehensive Python-based framework designed for real-time monitoring, data ingestion, and performance analysis of MetaTrader 5 (MT5) trading strategies. Built using the **Polylith Architecture**, it bridges the gap between MT5's MQL5 environment and modern Python data analysis tools.

> **Note:** This is a personal project developed for private use. It is designed for a single user and does not include multi-tenant or multi-user features.

## 🚀 Features

- **Real-Time Data Ingestion:** A high-performance TCP server that receives trade deals, equity updates, and runtime snapshots directly from an MQL5 Expert Advisor.
- **Optimized Time-Series Storage:** Leverages **TimescaleDB** (PostgreSQL) hypertables for efficient, high-frequency storage of deals and equity curves.
- **Advanced Financial Analytics:** Computes metrics like Sharpe Ratio, Drawdown, Win Rate, and portfolio correlations using **Pandas** and **QuantStats**.
- **Interactive Web Dashboard:** A **FastAPI** web application providing real-time visualizations via WebSockets.
- **Robust CLI:** A **Typer**-based command-line interface for easy management, database initialization, and terminal reporting.

## 🏗️ Architecture (Polylith)

The project is structured around the Polylith architecture, separating business logic from entry points:

- **Components (`components/`)**: Pure, reusable business logic and infrastructure layers.
  - `tradingmonitor_ingestion`: TCP Server and JSON payload validation via Pydantic.
  - `tradingmonitor_storage`: SQLAlchemy ORM, TimescaleDB interactions, and repository patterns.
  - `tradingmonitor_analytics`: Financial metric calculations via Pandas and QuantStats.
- **Bases (`bases/`)**: Entry points for the application.
  - `trading_monitor_cli`: The Typer CLI application.
  - `trading_monitor_dashboard`: The FastAPI web server and WebSocket handlers.

## 📋 Prerequisites

- **Python 3.12+**
- **uv** installed (`curl -LsSf https://astral.sh/uv/install.sh | sh`)
- **Docker & Docker Compose** (for TimescaleDB)
- **MetaTrader 5 Terminal** (for the MQL5 data source)

## 🛠️ Setup Instructions

1. **Install Dependencies:**
   ```bash
   uv sync
   ```

2. **Start the Database Infrastructure:**
   ```bash
   docker-compose up -d
   ```

3. **Initialize the Database Schema (Migrations & Hypertables):**
   ```bash
   uv run trading-monitor setup-db
   ```

4. **Start the System:**
   - **Ingestion & Web Dashboard:**
     ```bash
     uv run trading-monitor start-dashboard
     ```
     *(Starts the TCP server on port 5555 and the web interface on port 8000)*
   - **Ingestion Only (Headless):**
     ```bash
     uv run trading-monitor start-ingestion
     ```

5. **Verify Health:**
   ```bash
   uv run trading-monitor status
   ```

## 🔌 Connecting MetaTrader 5

To feed data into the system, you must run the provided Expert Advisor in your MT5 terminal:
1. Locate the EA source code (typically `projects/tradingmonitor/mt5/MetricsPublisher.mq5` or similar).
2. Compile it within MetaEditor and attach it to a chart.
3. The EA will establish a TCP connection and begin pushing deals and equity curve updates.

**Payload Example (Strategy Runtime Snapshot):**
```text
STRATEGY_RUNTIME {"time":1711737600,"magic":123456,"open_profit":48.35,"open_trades_count":2,"pending_orders_count":1}
```

## ⚙️ Configuration

Settings are managed via `pydantic-settings` and can be overridden using environment variables or a `.env` file at the root:

| Variable | Description | Default |
|----------|-------------|---------|
| `DATABASE_URL` | PostgreSQL connection string | `postgresql://postgres:password@localhost:5432/tradingmonitor` |
| `SERVER_HOST` | TCP Server listening address | `127.0.0.1` |
| `SERVER_PORT` | TCP Server port | `5555` |
| `DASHBOARD_HOST` | Web Dashboard listening address | `127.0.0.1` |
| `DASHBOARD_PORT` | Web Dashboard port | `8000` |
| `DEBUG` | Enable verbose logging | `False` |

## 👨‍💻 Development

### Data Conventions
- **Strategy ID:** Primarily identified by the MT5 **Magic Number** (stored as a string).
- **Account ID:** Primarily identified by the MT5 **Login Number**.

### Commands

**Running Tests:**
```bash
uv run pytest components/tradingmonitor_storage/test components/tradingmonitor_ingestion/test components/tradingmonitor_analytics/test bases/trading_monitor_cli/test bases/trading_monitor_dashboard/test
```

**Managing Database Migrations:**
High-frequency tables (`deals`, `equity_curve`) are initialized as TimescaleDB hypertables programmatically. Standard relational tables use Alembic:
```bash
uv run alembic revision --autogenerate -m "description of change"
uv run alembic upgrade head
```
