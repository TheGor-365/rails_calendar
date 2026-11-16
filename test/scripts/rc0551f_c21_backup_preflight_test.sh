#!/usr/bin/env bash
# Offline regression assertions: do not connect to or mutate PostgreSQL.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
target="$root/script/rc0551f_c21_backup_preflight.sh"
bash -n "$target"

tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT

if env RAILS_ENV=production bash "$target" >"$tmp/production.out" 2>&1; then
  echo 'FAIL: production must be refused without touching a database.' >&2
  exit 1
fi
grep -q 'STOP: RAILS_ENV must be development' "$tmp/production.out"

if env -u RAILS_ENV DATABASE_URL='postgresql://example.invalid/prod' bash "$target" >"$tmp/url.out" 2>&1; then
  echo 'FAIL: inherited DATABASE_URL must be refused.' >&2
  exit 1
fi
grep -q 'STOP: DATABASE_URL is set' "$tmp/url.out"

# --version via pg_wrapper may differ from actual pg_dump -h invocation;
# pin directly to the PG16 bin directory even for this read-only preflight.
grep -Fq 'PG_BIN="/usr/lib/postgresql/16/bin"' "$target"
grep -Fq '"$PG_BIN/$cmd" --version' "$target"
grep -Fq '"$PG_BIN/psql" -X' "$target"

# Structural prohibition. Psql read-only queries are deliberate.
if grep -Eq '^[[:space:]]*(createdb|dropdb|pg_dump[[:space:]]+.*-f|pg_restore[[:space:]]+.*-d|bin/rails[[:space:]]+db:)' "$target"; then
  echo 'FAIL: unexpected backup/migration or restore command in read-only preflight.' >&2
  exit 1
fi

# Regression: boolean output coerced by SQL string concatenation is "true"/"false",
# not the bare PostgreSQL boolean display "t"/"f". Use an explicit label.
grep -Fq "CASE WHEN inet_server_addr() IS NULL THEN 'socket' ELSE 'tcp' END" "$target"
grep -Fq '"$socket_only" == socket' "$target"
if grep -Fq '"$socket_only" == t' "$target"; then
  echo 'FAIL: implicit boolean-to-text socket mismatch must not return.' >&2
  exit 1
fi

echo 'RC055.1f C2.1 read-only backup preflight shell and production-deny checks: PASS'
