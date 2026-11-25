#!/usr/bin/env bash
# R0.4a — READ-ONLY checks for the verified C2.1b review DB.
# DOES NOT dump/restore, mutate PostgreSQL, create backup files, or change permissions.
# Run only from the user-controlled local Rails checkout. No URLs/credentials printed.
set -euo pipefail
umask 077

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
EXPECTED_DB="rails_calendar_rc0551f_c21b_review_20261117"
EXPECTED_ROLE="gor"
SOCKET="/var/run/postgresql"
PORT=5432
PG_BIN="/usr/lib/postgresql/16/bin"

die() { printf 'STOP: %s\n' "$1" >&2; exit 1; }

# Deny all dangerous environments *before* any database or filesystem inspection.
[[ "${RAILS_ENV:-development}" == development ]] ||
  die "Only local RAILS_ENV=development permitted."
[[ -z "${DATABASE_URL:-}" ]] ||
  die "DATABASE_URL is set; refusing inherited deployment connection."
[[ -n "${RC_LOCAL_DEV_DATABASE_URL:-}" ]] ||
  die "RC_LOCAL_DEV_DATABASE_URL must be set (never print it)."
[[ "$(id -un)" == "$EXPECTED_ROLE" ]] ||
  die "Expected the local gor OS user, not a privileged/other account."
[[ -d "$ROOT/storage" && ! -L "$ROOT/storage" ]] ||
  die "Local storage/ is absent or is a symlink."
[[ -S "$SOCKET/.s.PGSQL.$PORT" ]] ||
  die "The pinned PostgreSQL 16 local socket is missing."
for cmd in psql pg_dump pg_restore createdb; do
  [[ -x "$PG_BIN/$cmd" ]] || die "Pinned PostgreSQL 16 client is missing: $cmd"
  version="$("$PG_BIN/$cmd" --version)"
  [[ "$version" == *"(PostgreSQL) 16."* ]] ||
    die "Wrong PostgreSQL client version: $cmd"
done
for cmd in stat find du df awk wc sha256sum tar; do
  command -v "$cmd" >/dev/null || die "Required inspection tool missing: $cmd"
done

# Fixed database, role, socket and port: never follow a user-supplied DB URL.
# All queries explicitly request read-only sessions; only structural counts
# are returned. No credentials or individual data rows are displayed.
query() {
  PGOPTIONS='-c default_transaction_read_only=on' \
    "$PG_BIN/psql" -X -w -h "$SOCKET" -p "$PORT" -U "$EXPECTED_ROLE" \
      -d "$EXPECTED_DB" -v ON_ERROR_STOP=1 -Atc "$1"
}
identity="$(query "SELECT current_database() || '|' || current_user || '|' ||
  current_setting('server_version_num') || '|' ||
  CASE WHEN inet_server_addr() IS NULL THEN 'socket' ELSE 'tcp' END")" ||
  die "Cannot read the exact review database without interactive credentials."
IFS='|' read -r actual_db actual_role server_num transport <<< "$identity"
[[ "$actual_db" == "$EXPECTED_DB" && "$actual_role" == "$EXPECTED_ROLE" &&
   "$server_num" =~ ^16[0-9]{4}$ && "$transport" == socket ]] ||
  die "Database/role/PG16/transport identity mismatch. No backup allowed."

printf 'PASS R0.4a: exact review DB=%s; PostgreSQL=%s; role=%s; local socket\n' \
  "$actual_db" "$server_num" "$actual_role"

printf 'Tables (counts only; no client content):\n'
for table in schema_migrations users workspaces project_intakes \
             active_storage_blobs active_storage_attachments \
             domain_outbox_events; do
  exists="$(query "SELECT to_regclass('public.$table') IS NOT NULL")"
  if [[ "$exists" == t ]]; then
    count="$(query "SELECT count(*) FROM public.$table")"
    printf '  %-29s %s\n' "$table" "$count"
  else
    printf '  %-29s absent\n' "$table"
  fi
done

# Sessions are an observation, not a claim that every Rails/worker process
# has been stopped. Writer shutdown must be confirmed separately for backup.
sessions="$(query "SELECT count(*) FROM pg_stat_activity
  WHERE datname = current_database() AND pid <> pg_backend_pid()")"
db_bytes="$(query "SELECT pg_database_size(current_database())")"
printf 'Other connections currently using this DB: %s\n' "$sessions"
printf 'Current database size: %s bytes\n' "$db_bytes"

[[ -z "$(find -P "$ROOT/storage" -type l -print -quit)" ]] ||
  die "storage/ contains nested symlinks; inspect before any media archive."
[[ -z "$(find -P "$ROOT/storage" ! -type f ! -type d -print -quit)" ]] ||
  die "storage/ contains non-file or non-directory entries."
storage_mode="$(stat -c '%a' "$ROOT/storage")"
storage_owner="$(stat -c '%U' "$ROOT/storage")"
storage_group="$(stat -c '%G' "$ROOT/storage")"
[[ "$storage_owner" == "$EXPECTED_ROLE" ]] ||
  die "Storage directory owner differs from expected local owner."
files="$(find -P "$ROOT/storage" -type f -print | wc -l)"
storage_bytes="$(du -sb "$ROOT/storage" | awk '{print $1}')"
home_free_bytes="$(df -B1 --output=avail "$HOME" | awk 'END {print $1}')"
printf 'Storage: owner=%s group=%s mode=%s files=%s bytes=%s\n' \
  "$storage_owner" "$storage_group" "$storage_mode" "$files" "$storage_bytes"
printf 'Free space on HOME filesystem: %s bytes\n' "$home_free_bytes"
if (( (8#$storage_mode & 0020) != 0 )); then
  printf 'REVIEW: storage/ is group-writable; inspect group membership before private backup.\n'
fi
printf 'PASS: READ-ONLY R0.4a preflight. No archive, restore or migration performed.\n'
