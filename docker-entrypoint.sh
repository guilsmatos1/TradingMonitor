#!/bin/sh
set -e

echo "Running database migrations..."
.venv/bin/alembic upgrade head

echo "Initializing database schema..."
.venv/bin/trading-monitor setup-db

echo "Starting TradingMonitor dashboard..."
exec .venv/bin/trading-monitor start-dashboard \
    --host "${DASHBOARD_HOST:-0.0.0.0}" \
    --port "${DASHBOARD_PORT:-8000}" \
    --ingestion-host "${SERVER_HOST:-0.0.0.0}" \
    --ingestion-port "${SERVER_PORT:-5555}"
