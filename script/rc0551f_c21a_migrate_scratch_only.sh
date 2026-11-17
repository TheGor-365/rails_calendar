#!/usr/bin/env bash
# RC055.1f C2.1a — apply ONE new migration to the exact restored scratch DB.
# Does not target or modify source preview, Railway or production.
set -euo pipefail
umask 077

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
DB="rails_calendar_rc0551f_c21_restore_20261116T224810Z_7877"
PG_BIN="/usr/lib/postgresql/16/bin"
SOCKET="/var/run/postgresql"
ROLE="gor"
VERSION="20261117030000"

die() { printf 'STOP: %s\n' "$1" >&2; exit 1; }
[[ "$(printenv RAILS_ENV || true)" == "" || "$(printenv RAILS_ENV || true)" == "development" ]] ||
  die "Only local development is allowed."
[[ -z "$(printenv DATABASE_URL || true)" ]] || die "DATABASE_URL set: refusing potential production connection."
[[ -x "$PG_BIN/psql" ]] || die "Pinned PG16 psql not available."
[[ -S "$SOCKET/.s.PGSQL.5432" ]] || die "Local PG socket unavailable."
[[ "$("$PG_BIN/psql" --version)" == *"(PostgreSQL) 16."* ]] || die "Expected pinned PG16 client."

query() {
  PGOPTIONS="-c default_transaction_read_only=on" "$PG_BIN/psql" -X -w \
    -h "$SOCKET" -p 5432 -U "$ROLE" -d "$DB" -At -v ON_ERROR_STOP=1 -c "$1"
}
identity="$(query "SELECT current_database() || '|' || current_user || '|' || current_setting('server_version_num') || '|' || CASE WHEN inet_server_addr() IS NULL THEN 'socket' ELSE 'tcp' END")"
IFS='|' read -r actual_db actual_role server_num transport <<< "$identity"
[[ "$actual_db" == "$DB" && "$actual_role" == "$ROLE" &&
   "$server_num" == 16???? && "$transport" == socket ]] ||
  die "Scratch identity, role, local transport or PG16 server mismatch."

schema_state="$(query "SELECT CASE WHEN
 to_regclass('public.workspaces') IS NOT NULL AND
 to_regclass('public.ai_spend_entries') IS NOT NULL AND
 to_regclass('public.active_storage_blobs') IS NOT NULL AND
 to_regclass('public.active_storage_attachments') IS NOT NULL AND
 to_regclass('public.schema_migrations') IS NOT NULL AND
 to_regclass('public.owner_ai_conversations') IS NULL AND
 to_regclass('public.owner_ai_messages') IS NULL
 THEN 'ready' ELSE 'review' END")"
[[ "$schema_state" == ready ]] || die "Scratch DB is missing restored tables or already has new AI tables; manual review required."

applied="$(query "SELECT count(*) FROM public.schema_migrations WHERE version = '$VERSION'")"
[[ "$applied" == 0 ]] || die "Migration version is already recorded on scratch."

printf 'PASS: exact restored SCRATCH database, PG16 local socket, Active Storage and unmodified schema.\n'
[[ "$(printenv RC_CONFIRM_SCRATCH_MIGRATION || true)" == YES ]] ||
  die "To apply only the scratch migration, explicitly pass RC_CONFIRM_SCRATCH_MIGRATION=YES."

cd "$ROOT"
export RAILS_ENV="development"
export RC_EXPECTED_SCRATCH_DB="$DB"
export RC_LOCAL_DEV_DATABASE_URL="postgresql://gor@localhost/$DB?host=%2Fvar%2Frun%2Fpostgresql"

# Confirm the *actual Rails connection* before any write.
bin/rails runner '
  c = ActiveRecord::Base.connection
  db = c.select_value("SELECT current_database()")
  transport = c.select_value("SELECT CASE WHEN inet_server_addr() IS NULL THEN '\''socket'\'' ELSE '\''tcp'\'' END")
  version = c.select_value("SHOW server_version_num").to_i
  abort("STOP: Rails connection is NOT the local PG16 restored scratch DB") unless
    db == ENV.fetch("RC_EXPECTED_SCRATCH_DB") && transport == "socket" &&
    version >= 160000 && version < 170000
  puts "PASS: Rails connection targets exact restored scratch DB."
'
# Target one migration, not db:prepare, db:schema:load, db:reset or all pending migrations.
bin/rails db:migrate:up VERSION="$VERSION"

recorded="$(query "SELECT count(*) FROM public.schema_migrations WHERE version = '$VERSION'")"
tables="$(query "SELECT CASE WHEN
 to_regclass('public.owner_ai_conversations') IS NOT NULL AND
 to_regclass('public.owner_ai_messages') IS NOT NULL
 THEN 'ready' ELSE 'missing' END")"
[[ "$recorded" == 1 && "$tables" == ready ]] || die "Scratch migration verification FAILED; preserve scratch for review."

printf 'PASS: isolated scratch C2.1a migration recorded; both new tables exist.\n'
printf 'Original preview DB and private media not targeted by this script.\n'
printf 'Inspect any db/schema.rb working-tree diff before committing; do not reset source DB.\n'
git status -sb
