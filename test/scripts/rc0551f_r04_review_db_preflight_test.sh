#!/usr/bin/env bash
# Offline deny-path and structural regression for the R0.4a READ-ONLY script.
# CI MUST NEVER connect to the user's database, dump media or restore a DB.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TARGET="$ROOT/script/rc0551f_r04_review_db_preflight.sh"
bash -n "$TARGET"

tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT

if env RAILS_ENV=production RC_LOCAL_DEV_DATABASE_URL='postgresql://invalid.example/preview' \
  bash "$TARGET" >"$tmp/prod.out" 2>&1; then
  echo 'FAIL: production RAILS_ENV permitted' >&2
  exit 1
fi
grep -Fq 'STOP: Only local RAILS_ENV=development permitted.' "$tmp/prod.out"

if env -u RAILS_ENV DATABASE_URL='postgresql://invalid.example/prod' \
  RC_LOCAL_DEV_DATABASE_URL='postgresql://invalid.example/preview' \
  bash "$TARGET" >"$tmp/remote.out" 2>&1; then
  echo 'FAIL: inherited DATABASE_URL permitted' >&2
  exit 1
fi
grep -Fq 'STOP: DATABASE_URL is set' "$tmp/remote.out"

if env -u RAILS_ENV -u DATABASE_URL -u RC_LOCAL_DEV_DATABASE_URL \
  bash "$TARGET" >"$tmp/missing.out" 2>&1; then
  echo 'FAIL: absent explicit review DB context permitted' >&2
  exit 1
fi
grep -Fq 'STOP: RC_LOCAL_DEV_DATABASE_URL must be set' "$tmp/missing.out"

grep -Fq 'EXPECTED_DB="rails_calendar_rc0551f_c21b_review_20261117"' "$TARGET"
grep -Fq 'EXPECTED_ROLE="gor"' "$TARGET"
grep -Fq 'PG_BIN="/usr/lib/postgresql/16/bin"' "$TARGET"
grep -Fq "PGOPTIONS='-c default_transaction_read_only=on'" "$TARGET"
grep -Fq '[[ "$actual_db" == "$EXPECTED_DB"' "$TARGET"
grep -Fq '"$server_num" =~ ^16[0-9]{4}$' "$TARGET"
grep -Fq '"$transport" == socket' "$TARGET"
grep -Fq 'find -P "$ROOT/storage" -type l' "$TARGET"
grep -Fq 'storage/ is group-writable' "$TARGET"

# No backup/DDL/download, no destructive filesystem operation even if
# someone later modifies the script. Read-only preflight is a strict gate.
if grep -Eq '^[[:space:]]*(createdb|dropdb|pg_dump[[:space:]]+.*(-f|>)|pg_restore[[:space:]]+.*-d|rm[[:space:]]+-rf|chmod[[:space:]]|chown[[:space:]]|bin/rails[[:space:]]+db:)' "$TARGET"; then
  echo 'FAIL: unexpected filesystem/database writer in read-only preflight' >&2
  exit 1
fi
echo 'R0.4a exact local review DB and storage preflight — offline deny checks: PASS'
