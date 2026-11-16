#!/usr/bin/env bash
# RC055.1f C2.1 — READ-ONLY preview backup preflight. No dump, SQL DDL or deletions.
# Run from the verified local Rails checkout. Do not paste private env contents.
set -euo pipefail
umask 077

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
EXPECTED_DB="rails_calendar_mvp_preview_20261112"
SOCKET="/var/run/postgresql"
DB_USER="${RC_BACKUP_DB_USER:-$(id -un)}"

die() { printf 'STOP: %s\n' "$1" >&2; exit 1; }
[[ "${RAILS_ENV:-development}" == development ]] || die "RAILS_ENV must be development, never production/test."
[[ -z "${DATABASE_URL:-}" ]] || die "DATABASE_URL is set. Unset it in a separate preview-only shell before preflight."
[[ -d "$ROOT/storage" && ! -L "$ROOT/storage" ]] || die "Local storage/ is absent or a symlink; inspect storage config first."
[[ -S "$SOCKET/.s.PGSQL.5432" ]] || die "Expected local PostgreSQL Unix socket unavailable at $SOCKET."
command -v pg_dump >/dev/null || die "pg_dump missing"
command -v pg_restore >/dev/null || die "pg_restore missing"
command -v psql >/dev/null || die "psql missing"
command -v createdb >/dev/null || die "createdb missing"
command -v sha256sum >/dev/null || die "sha256sum missing"
command -v tar >/dev/null || die "tar missing"

for cmd in pg_dump pg_restore; do
  ver="$($cmd --version)"
  [[ "$ver" == *"(PostgreSQL) 16."* ]] || die "$cmd must be major version 16; actual: $ver"
done

# No SQL writes. Auth is via the local socket; do not pass credentials on command line.
db_info="$(PGOPTIONS='-c default_transaction_read_only=on' psql -X -w -h "$SOCKET" -p 5432 -U "$DB_USER" -d "$EXPECTED_DB" -v ON_ERROR_STOP=1 -Atc "SELECT current_database() || '|' || current_user || '|' || current_setting('server_version') || '|' || (inet_server_addr() IS NULL)")" || die "Cannot connect to the exact local preview DB via socket without interactive credentials."
IFS='|' read -r db_name server_role server_version socket_only <<< "$db_info"
[[ "$db_name" == "$EXPECTED_DB" && "$socket_only" == t && "$server_version" == 16.* ]] || die "Database identity / local socket / PG16 mismatch."

printf 'PASS: preview-only DB=%s role=%s PostgreSQL=%s, local Unix socket\n' "$db_name" "$server_role" "$server_version"
printf 'Read-only row counts (not a content export):\n'
for table in users workspaces professional_profiles project_intakes service_offerings service_offering_versions ai_spend_entries active_storage_blobs active_storage_attachments; do
  exists="$(PGOPTIONS='-c default_transaction_read_only=on' psql -X -w -h "$SOCKET" -p 5432 -U "$DB_USER" -d "$EXPECTED_DB" -v ON_ERROR_STOP=1 -Atc "SELECT to_regclass('public.$table') IS NOT NULL")"
  if [[ "$exists" == t ]]; then
    count="$(PGOPTIONS='-c default_transaction_read_only=on' psql -X -w -h "$SOCKET" -p 5432 -U "$DB_USER" -d "$EXPECTED_DB" -v ON_ERROR_STOP=1 -Atc "SELECT count(*) FROM public.$table")"
    printf '  %-30s %s\n' "$table" "$count"
  else
    printf '  %-30s MISSING (schema reconciliation required)\n' "$table"
  fi
done

symlinks="$(find "$ROOT/storage" -type l -print | wc -l)"
[[ "$symlinks" -eq 0 ]] || die "Storage contains symlinks; inspect before making a private archive."
files="$(find "$ROOT/storage" -type f -print | wc -l)"
bytes="$(du -sb "$ROOT/storage" | awk '{print $1}')"
free_kb="$(df -Pk "$HOME" | awk 'END {print $4}')"
printf 'Private storage: %s files, %s bytes, %s KB free in home filesystem\n' "$files" "$bytes" "$free_kb"
printf 'PASS: READ-ONLY checks finished. NO backup created and NO restore verified yet.\n'
