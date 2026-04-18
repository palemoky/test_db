#!/bin/bash
# =============================================================================
# PostgreSQL initialization script for test_db employees sample database.
# Runs inside /docker-entrypoint-initdb.d/ as user POSTGRES_USER.
#
# Steps:
#   1. Create schema via postgresql/employees.sql (creates employees database)
#   2. Load all data dump files (stripping MySQL backtick quoting)
#   3. Load stored procedures/functions (postgresql/objects.sql)
# =============================================================================
set -eo pipefail

echo "==> [test_db] Loading employees sample database for PostgreSQL..."

# ---------------------------------------------------------------------------
# Step 1: Create database schema
# postgresql/employees.sql handles: DROP DATABASE → CREATE DATABASE → \connect
# We must connect to the default postgres db first, then switch.
# ---------------------------------------------------------------------------
echo "==> Creating schema..."
psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -f /init/postgresql/employees.sql

# ---------------------------------------------------------------------------
# Step 2: Load data dump files (strip MySQL-specific backtick quoting)
# The .dump files use INSERT syntax compatible with both MySQL and PostgreSQL,
# except for backtick-quoted identifiers which PostgreSQL does not support.
# ---------------------------------------------------------------------------
for table in departments employees dept_emp dept_manager titles; do
    echo "==> Loading $table..."
    sed 's/`//g' "/init/load_${table}.dump" \
        | psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d employees -q
done

for i in 1 2 3; do
    echo "==> Loading salaries part $i..."
    sed 's/`//g' "/init/load_salaries${i}.dump" \
        | psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d employees -q
done

# ---------------------------------------------------------------------------
# Step 3: Load stored procedures and views (optional, best-effort)
# ---------------------------------------------------------------------------
echo "==> Loading stored procedures/functions..."
psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d employees -f /init/postgresql/objects.sql

echo "==> Employees database loaded successfully!"

# ---------------------------------------------------------------------------
# Generate /etc/motd with real connection credentials so users can find them
# easily via `docker logs` or `docker exec -it <ctr> bash`.
# ---------------------------------------------------------------------------
PG_VER=$(psql --version 2>&1 | grep -oP '\d+\.\d+' | head -1)
PASS="${POSTGRES_PASSWORD:-test}"
USER="${POSTGRES_USER:-postgres}"
SEP=$(printf '═%.0s' {1..62})
TEXT_W=60   # inner text width (between "║  " and "║")

_row() { printf "║  %-${TEXT_W}s║\n" "$1"; }

{
  printf "╔%s╗\n" "$SEP"
  _row "test_db  ·  Employees Sample Database"
  _row "PostgreSQL ${PG_VER}  ·  ~300k employees  ·  ~2.8M salary records"
  printf "╠%s╣\n" "$SEP"
  _row "Host:      127.0.0.1 (or mapped host)"
  _row "Port:      5432"
  _row "User:      ${USER}"
  _row "Password:  ${PASS}"
  _row "Database:  employees"
  printf "╠%s╣\n" "$SEP"
  _row "Quick connect:"
  _row "  psql -h 127.0.0.1 -p 5432 -U ${USER} -d employees"
  printf "╚%s╝\n" "$SEP"
} | tee /etc/motd
