#!/usr/bin/env bash
# Offline fail-closed guard assertions only. Never connect to PostgreSQL in CI.
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
script="$root/script/rc0551f_c21a_migrate_scratch_only.sh"
bash -n "$script"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT

if env RAILS_ENV=production RC_CONFIRM_SCRATCH_MIGRATION=YES bash "$script" >"$tmp/prod" 2>&1; then
  echo "FAIL: scratch-only script accepted RAILS_ENV=production" >&2
  exit 1
fi
grep -Fq "Only local development is allowed" "$tmp/prod"

if env -u RAILS_ENV DATABASE_URL="postgresql://example.invalid/production" RC_CONFIRM_SCRATCH_MIGRATION=YES bash "$script" >"$tmp/url" 2>&1; then
  echo "FAIL: scratch-only script accepted DATABASE_URL" >&2
  exit 1
fi
grep -Fq "DATABASE_URL set" "$tmp/url"

grep -Fq 'DB="rails_calendar_rc0551f_c21_restore_20261116T224810Z_7877"' "$script"
grep -Fq 'PG_BIN="/usr/lib/postgresql/16/bin"' "$script"
grep -Fq '[[ "$schema_state" == ready ]]' "$script"
grep -Fq 'RC_CONFIRM_SCRATCH_MIGRATION=YES' "$script"
grep -Fq 'RC_LOCAL_DEV_DATABASE_URL="postgresql://gor@localhost/$DB?host=%2Fvar%2Frun%2Fpostgresql"' "$script"
grep -Fq 'Rails connection is NOT the local PG16 restored scratch DB' "$script"
grep -Fq 'db:migrate:up VERSION="$VERSION"' "$script"
grep -Fq 'VERSION="20261117030000"' "$script"
if grep -Eq 'db:(reset|drop|schema:load|prepare)|dropdb|pg_restore[[:space:]].*--clean' "$script"; then
  echo "FAIL: destructive or broad DB task present" >&2
  exit 1
fi
echo "RC055.1f C2.1a scratch-only migration deny-path and target assertions: PASS"
