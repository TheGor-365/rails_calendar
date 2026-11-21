#!/usr/bin/env bash
# R0.4b offline deny-path and structural tests. NEVER connect to a real database,
# create a backup directory, or grant consent in GitHub CI.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
SCRIPT="$ROOT/script/rc0551f_r04_review_db_backup_restore.sh"
bash -n "$SCRIPT"

scratch="$(mktemp -d)"
trap 'rm -rf -- "$scratch"' EXIT

if env RAILS_ENV=production DATABASE_URL='' \
  RC_CONFIRM_SOURCE_DB=rails_calendar_rc0551f_c21b_review_20261117 \
  RC_CONFIRM_WRITERS_STOPPED=YES RC_CONFIRM_PRIVATE_BACKUP_AND_RESTORE=YES \
  RC_CONFIRM_STORAGE_GROUP_REVIEW=YES \
  bash "$SCRIPT" > "$scratch/deny-prod.txt" 2>&1; then
  echo 'FAIL: production script invocation must be denied' >&2
  exit 1
fi
grep -Fq 'STOP R0.4b: Production/test environment denied' "$scratch/deny-prod.txt"

if env -u RAILS_ENV DATABASE_URL='postgresql://bad.invalid/prod' \
  RC_CONFIRM_SOURCE_DB=rails_calendar_rc0551f_c21b_review_20261117 \
  RC_CONFIRM_WRITERS_STOPPED=YES RC_CONFIRM_PRIVATE_BACKUP_AND_RESTORE=YES \
  RC_CONFIRM_STORAGE_GROUP_REVIEW=YES \
  bash "$SCRIPT" > "$scratch/deny-url.txt" 2>&1; then
  echo 'FAIL: inherited DATABASE_URL must be denied' >&2
  exit 1
fi
grep -Fq 'STOP R0.4b: DATABASE_URL is set' "$scratch/deny-url.txt"

if env -u DATABASE_URL -u RC_CONFIRM_SOURCE_DB -u RC_CONFIRM_WRITERS_STOPPED \
  -u RC_CONFIRM_PRIVATE_BACKUP_AND_RESTORE -u RC_CONFIRM_STORAGE_GROUP_REVIEW \
  RAILS_ENV=development RC_LOCAL_DEV_DATABASE_URL=postgresql://example.invalid/review \
  bash "$SCRIPT" > "$scratch/deny-source.txt" 2>&1; then
  echo 'FAIL: missing source DB confirmation must be denied' >&2
  exit 1
fi
grep -Fq 'RC_CONFIRM_SOURCE_DB must equal the exact review database' "$scratch/deny-source.txt"

if env -u DATABASE_URL -u RC_CONFIRM_WRITERS_STOPPED \
  RC_CONFIRM_SOURCE_DB=rails_calendar_rc0551f_c21b_review_20261117 \
  RAILS_ENV=development RC_LOCAL_DEV_DATABASE_URL=postgresql://example.invalid/review \
  bash "$SCRIPT" > "$scratch/deny-writers.txt" 2>&1; then
  echo 'FAIL: non-confirmed writers must be denied' >&2
  exit 1
fi
grep -Fq 'RC_CONFIRM_WRITERS_STOPPED=YES' "$scratch/deny-writers.txt"

if env -u DATABASE_URL -u RC_CONFIRM_PRIVATE_BACKUP_AND_RESTORE \
  RC_CONFIRM_SOURCE_DB=rails_calendar_rc0551f_c21b_review_20261117 \
  RC_CONFIRM_WRITERS_STOPPED=YES RAILS_ENV=development \
  RC_LOCAL_DEV_DATABASE_URL=postgresql://example.invalid/review \
  bash "$SCRIPT" > "$scratch/deny-restore.txt" 2>&1; then
  echo 'FAIL: unapproved backup and scratch restore must be denied' >&2
  exit 1
fi
grep -Fq 'RC_CONFIRM_PRIVATE_BACKUP_AND_RESTORE=YES' "$scratch/deny-restore.txt"

grep -Fq 'EXPECTED_DB="rails_calendar_rc0551f_c21b_review_20261117"' "$SCRIPT"
grep -Fq 'PG_BIN="/usr/lib/postgresql/16/bin"' "$SCRIPT"
grep -Fq 'SOCKET="/var/run/postgresql"' "$SCRIPT"
grep -Fq 'BACKUP_ROOT="$HOME/.local/share/rails-calendar/review-backups-r04"' "$SCRIPT"
grep -Fq "PGOPTIONS='-c default_transaction_read_only=on'" "$SCRIPT"
grep -Fq '"$resolved" == "$identity"' "$SCRIPT"
grep -Fq 'rolcreatedb OR rolsuper' "$SCRIPT"
grep -Fq 'find -P "$ROOT/storage" -type l' "$SCRIPT"
grep -Fq '"$ROOT" == "$HOME/rails_calendar_ai_c21c"' "$SCRIPT"
grep -Fq 'primary_members="$(getent passwd' "$SCRIPT"
grep -Fq 'supplemental_members="$(getent group' "$SCRIPT"
grep -Fq 'service.is_a?(ActiveStorage::Service::DiskService)' "$SCRIPT"
grep -Fq '"$actual_media_root" == "$ROOT/storage"' "$SCRIPT"
grep -Fq 'ss -H -ltn "sport = :3002"' "$SCRIPT"
grep -Fq '4 * db_bytes + 3 * media_bytes + 2147483648' "$SCRIPT"
grep -Fq '"$PG_BIN/pg_dump" -w -Fc --no-owner --no-acl' "$SCRIPT"
grep -Fq '"$PG_BIN/pg_restore" -l "$backup/review.pgcustom"' "$SCRIPT"
grep -Fq '"$PG_BIN/createdb" -w -h "$SOCKET" -p "$PORT"' "$SCRIPT"
grep -Fq '"$PG_BIN/pg_restore" -w --exit-on-error --no-owner --no-acl' "$SCRIPT"
grep -Fq 'diff -qr "$ROOT/storage" "$backup/media_restore/storage"' "$SCRIPT"
grep -Fq 'sha256sum -c SHA256SUMS' "$SCRIPT"
grep -Fq 'schema_migrations differ' "$SCRIPT"
grep -Fq 'backup_and_scratch_preserved=yes' "$SCRIPT"

# No destructive DB/file cleanup and no unreviewed automatic schema mutation.
if grep -Eq '^[[:space:]]*(dropdb|rm[[:space:]]+-rf|chmod[[:space:]]|chown[[:space:]]|bin/rails[[:space:]]+db:)' "$SCRIPT"; then
  echo 'FAIL: destructive or unreviewed data mutation in R0.4b writer' >&2
  exit 1
fi
echo 'R0.4b exact review DB private archive and scratch restore — OFFLINE deny tests: PASS'
