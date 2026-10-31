#!/usr/bin/env bash
# Runs all migrations plus the security suite against a throwaway local Postgres.
# Needs PostgreSQL 15+ binaries (initdb, pg_ctl, psql) on PATH or in a Homebrew
# keg. Usage: supabase/tests/run_local.sh
set -euo pipefail
cd "$(dirname "$0")/.."

for d in /opt/homebrew/opt/postgresql@*/bin /usr/lib/postgresql/*/bin; do
  [ -d "$d" ] && PATH="$d:$PATH"
done
command -v initdb >/dev/null || { echo "initdb not found; install PostgreSQL"; exit 2; }

if [ -z "${LC_ALL:-}" ]; then
  if locale -a 2>/dev/null | grep -qi "^en_US.utf-\?8$"; then export LC_ALL=en_US.UTF-8; else export LC_ALL=C.UTF-8; fi
fi
WORK="$(mktemp -d /tmp/crowddj-pg.XXXXXX)"
SOCK="$WORK/s"; mkdir -p "$SOCK"
cleanup() { pg_ctl -D "$WORK/data" stop -m immediate >/dev/null 2>&1 || true; rm -rf "$WORK"; }
trap cleanup EXIT

initdb -D "$WORK/data" -U postgres >/dev/null
pg_ctl -D "$WORK/data" -o "-p 54398 -k $SOCK -c listen_addresses=''" -l "$WORK/pg.log" -w start >/dev/null
P() { psql -h "$SOCK" -p 54398 -U postgres -v ON_ERROR_STOP=1 -q "$@"; }

P -d postgres -c "create database t"
P -d t -f tests/stubs.sql 2>&1 | grep -v "wal_level\|HINT" || true
for f in $(ls migrations/2026*.sql | grep -v "${EXCLUDE:-^$}"); do echo "applying $f"; P -d t -f "$f"; done
echo "re-applying the latest migration to prove it is idempotent"
last="$(ls migrations/2026*.sql | tail -1)"; P -d t -f "$last"
echo "running security suite"
P -d t -f tests/security.sql
