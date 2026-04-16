#!/bin/sh
set -e

# Extract DB connection info from DATABASE_URL for psql commands
# Expected format: postgresql://user:password@host:port/dbname
DB_URL="${DATABASE_URL}"
DB_HOST=$(echo "$DB_URL" | sed -E 's|.*@([^:/]+).*|\1|')
DB_PORT=$(echo "$DB_URL" | sed -E 's|.*:([0-9]+)/.*|\1|')
DB_USER=$(echo "$DB_URL" | sed -E 's|.*://([^:]+):.*|\1|')
DB_PASS=$(echo "$DB_URL" | sed -E 's|.*://[^:]+:([^@]+)@.*|\1|')
DB_NAME=$(echo "$DB_URL" | sed -E 's|.*/([^?]+).*|\1|')

echo "Waiting for database at ${DB_HOST}:${DB_PORT}..."
until PGPASSWORD="$DB_PASS" pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -q; do
    sleep 2
done

echo "Ensuring database '${DB_NAME}' exists..."
PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -tc \
    "SELECT 1 FROM pg_database WHERE datname = '${DB_NAME}'" \
    | grep -q 1 || \
    PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -c \
    "CREATE DATABASE \"${DB_NAME}\""

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
