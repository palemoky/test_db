#!/bin/bash
# shellcheck disable=SC2086
set -eo pipefail

echo "==> [test_db] Loading employees sample database..."

# ---------------------------------------------------------------------------
# Detect MySQL version to decide whether --commands flag is needed.
# The --commands flag is required in MySQL 9.5+ because the default value of
# the `--commands` option changed to FALSE (SOURCE no longer works without it).
# ---------------------------------------------------------------------------
MYSQL_FULL_VER=$(mysqld --version 2>&1 | grep -oP '\d+\.\d+\.\d+' | head -1)
MAJOR=$(echo "$MYSQL_FULL_VER" | cut -d. -f1)
MINOR=$(echo "$MYSQL_FULL_VER" | cut -d. -f2)

EXTRA_ARGS=""
if [ "$MAJOR" -gt 9 ] || { [ "$MAJOR" -eq 9 ] && [ "$MINOR" -ge 5 ]; }; then
    EXTRA_ARGS="--commands"
    echo "==> MySQL ${MYSQL_FULL_VER} detected: enabling --commands flag for SOURCE support"
else
    echo "==> MySQL ${MYSQL_FULL_VER} detected"
fi

# ---------------------------------------------------------------------------
# employees.sql uses relative `SOURCE` commands, so we must cd to /init first.
# The mysql client resolves SOURCE paths relative to its working directory.
# The root password is set via MYSQL_ROOT_PASSWORD by the official entrypoint.
# On Linux containers the client connects via Unix socket by default.
# ---------------------------------------------------------------------------
cd /init

echo "==> Executing employees.sql (this may take a few minutes)..."
mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" $EXTRA_ARGS < employees.sql

echo "==> Employees database loaded successfully!"

# ---------------------------------------------------------------------------
# Generate /etc/motd with real connection credentials so users can find them
# easily via `docker logs` or `docker exec -it <ctr> bash`.
# ---------------------------------------------------------------------------
PASS="${MYSQL_ROOT_PASSWORD:-test}"
VER="${MYSQL_FULL_VER:-unknown}"
SEP=$(printf '═%.0s' {1..62})
TEXT_W=60   # inner text width (between "║  " and "║")

_row() { printf "║  %-${TEXT_W}s║\n" "$1"; }

{
  printf "╔%s╗\n" "$SEP"
  _row "test_db  ·  Employees Sample Database"
  _row "MySQL ${VER}  ·  ~300k employees  ·  ~2.8M salary records"
  printf "╠%s╣\n" "$SEP"
  _row "Host:      127.0.0.1 (or mapped host)"
  _row "Port:      3306"
  _row "User:      root"
  _row "Password:  ${PASS}"
  _row "Database:  employees"
  printf "╠%s╣\n" "$SEP"
  _row "Quick connect:"
  _row "  mysql -h 127.0.0.1 -P 3306 -uroot -p${PASS} employees"
  printf "╚%s╝\n" "$SEP"
} | tee /etc/motd
