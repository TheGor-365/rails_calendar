#!/usr/bin/env bash
# R0.4b — owner-approved PRIVATE backup of the exact PG16 review DB and storage,
# followed by a verified restore into a NEW scratch database. NEVER production.
# This script is intentionally NOT invoked by CI; only offline deny checks run.
set -euo pipefail
umask 077

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
EXPECTED_DB="rails_calendar_rc0551f_c21b_review_20261117"
EXPECTED_ROLE="gor"
SOCKET="/var/run/postgresql"
PORT=5432
PG_BIN="/usr/lib/postgresql/16/bin"
BACKUP_ROOT="$HOME/.local/share/rails-calendar/review-backups-r04"

die() { printf 'STOP R0.4b: %s\n' "$1" >&2; exit 1; }

# No writes whatsoever until the owner has approved the source, stopped
# all writers and separately consented to a local backup + scratch creation.
[[ "${RAILS_ENV:-development}" == development ]] ||
  die "Production/test environment denied."
[[ -z "${DATABASE_URL:-}" ]] ||
  die "DATABASE_URL is set; refusing inherited production connection."
[[ -n "${RC_LOCAL_DEV_DATABASE_URL:-}" ]] ||
  die "Explicit RC_LOCAL_DEV_DATABASE_URL required (never print its value)."
[[ "$(id -un)" == "$EXPECTED_ROLE" ]] ||
  die "Expected the unprivileged local gor account."
[[ "$ROOT" == "$HOME/rails_calendar_ai_c21c" ]] ||
  die "Script must run from the exact reviewed local Rails checkout."
[[ "${RC_CONFIRM_SOURCE_DB:-}" == "$EXPECTED_DB" ]] ||
  die "Explicit RC_CONFIRM_SOURCE_DB must equal the exact review database name."
[[ "${RC_CONFIRM_WRITERS_STOPPED:-}" == YES ]] ||
  die "Stop only the affected app/workers and set RC_CONFIRM_WRITERS_STOPPED=YES."
[[ "${RC_CONFIRM_PRIVATE_BACKUP_AND_RESTORE:-}" == YES ]] ||
  die "Private backup and NEW scratch restore need RC_CONFIRM_PRIVATE_BACKUP_AND_RESTORE=YES."
[[ "${RC_CONFIRM_STORAGE_GROUP_REVIEW:-}" == YES ]] ||
  die "Review storage group membership and set RC_CONFIRM_STORAGE_GROUP_REVIEW=YES."

[[ -d "$ROOT/storage" && ! -L "$ROOT/storage" ]] ||
  die "storage/ missing or top-level symlink."
[[ -S "$SOCKET/.s.PGSQL.$PORT" ]] ||
  die "Pinned local PostgreSQL socket unavailable."
for cmd in psql pg_dump pg_restore createdb; do
  [[ -x "$PG_BIN/$cmd" ]] || die "Pinned PostgreSQL 16 client missing: $cmd"
  [[ "$("$PG_BIN/$cmd" --version)" == *"(PostgreSQL) 16."* ]] ||
    die "Client version mismatch: $cmd"
done
for cmd in ss tar sha256sum diff df du stat find date mktemp awk; do
  command -v "$cmd" >/dev/null || die "Required command unavailable: $cmd"
done
[[ -z "$(find -P "$ROOT/storage" -type l -print -quit)" ]] ||
  die "Nested storage symlink; no archive allowed."
[[ -z "$(find -P "$ROOT/storage" ! -type d ! -type f -print -quit)" ]] ||
  die "Unexpected storage entry type."
[[ "$(stat -c '%U' "$ROOT/storage")" == "$EXPECTED_ROLE" ]] ||
  die "Storage owner mismatch."
[[ "$(stat -c '%G' "$ROOT/storage")" == "$EXPECTED_ROLE" ]] ||
  die "Storage group mismatch; stop for manual review."

# The observed directory is group-writable (0775). Before archiving private
# files, reject a group shared with *any* other primary/supplementary accounts.
command -v getent >/dev/null || die "getent required for storage group audit."
storage_gid="$(stat -c '%g' "$ROOT/storage")"
primary_members="$(getent passwd | awk -F: -v gid="$storage_gid" '$4 == gid { print $1 }')"
supplemental_members="$(getent group "$EXPECTED_ROLE" | awk -F: '{ print $4 }')"
[[ "$primary_members" == "$EXPECTED_ROLE" && -z "$supplemental_members" ]] ||
  die "Group-writable storage belongs to a shared group; stop for permission review."

# Do not assume a config name alone proves where Active Storage actually writes.
[[ -f "$ROOT/bin/rails" ]] || die "Rails executable missing in reviewed checkout."
actual_media_root="$(cd "$ROOT" &&
  ASDF_RUBY_VERSION=3.4.13 RAILS_ENV=development RC_GROK_ENABLED=false \
  PGOPTIONS='-c default_transaction_read_only=on' ruby bin/rails runner '
    service = ActiveStorage::Blob.service
    abort("STOP: non-local Active Storage service") unless
      service.is_a?(ActiveStorage::Service::DiskService)
    puts File.realpath(service.root.to_s)
  ')" || die "Cannot verify effective Active Storage disk root."
[[ "$actual_media_root" == "$ROOT/storage" ]] ||
  die "Effective Active Storage root is not the reviewed storage/ directory."

# The original :3001 server is never stopped by this tool. The user must
# identify active writers before running it; :3002 must be stopped too.
if ss -H -ltn "sport = :3002" | grep -q .; then
  die "Port 3002 is listening. Stop the review app/writers before backup."
fi

query() {
  PGOPTIONS='-c default_transaction_read_only=on' \
    "$PG_BIN/psql" -X -w -h "$SOCKET" -p "$PORT" -U "$EXPECTED_ROLE" \
      -d "$1" -v ON_ERROR_STOP=1 -Atc "$2"
}
identity="$(query "$EXPECTED_DB" "SELECT current_database() || '|' || current_user || '|' ||
  current_setting('server_version_num') || '|' ||
  CASE WHEN inet_server_addr() IS NULL THEN 'socket' ELSE 'tcp' END")" ||
  die "Cannot open exact local review DB with local socket."
IFS='|' read -r db role server_num transport <<< "$identity"
[[ "$db" == "$EXPECTED_DB" && "$role" == "$EXPECTED_ROLE" &&
   "$server_num" =~ ^16[0-9]{4}$ && "$transport" == socket ]] ||
  die "Review DB identity/role/PG16/transport mismatch."

# Also verify the environment-provided URL RESOLVES to that same local DB.
# A mismatch must not be ignored just because the writer uses a fixed socket.
resolved="$(PGOPTIONS='-c default_transaction_read_only=on' \
  "$PG_BIN/psql" -X -w -d "$RC_LOCAL_DEV_DATABASE_URL" \
  -v ON_ERROR_STOP=1 -Atc "SELECT current_database() || '|' || current_user || '|' ||
    current_setting('server_version_num') || '|' ||
    CASE WHEN inet_server_addr() IS NULL THEN 'socket' ELSE 'tcp' END")" ||
  die "RC_LOCAL_DEV_DATABASE_URL could not be verified.")
[[ "$resolved" == "$identity" ]] ||
  die "Configured Rails DB does not match the exact reviewed local DB."

for table in users workspaces project_intakes schema_migrations \
             active_storage_blobs active_storage_attachments; do
  [[ "$(query "$EXPECTED_DB" "SELECT to_regclass('public.$table') IS NOT NULL")" == t ]] ||
    die "Required source table missing: $table"
done
[[ "$(query "$EXPECTED_DB" "SELECT to_regclass('public.domain_outbox_events') IS NULL")" == t ]] ||
  die "Outbox already present; stop for schema/drift review."
external_blobs="$(query "$EXPECTED_DB" "SELECT count(*) FROM public.active_storage_blobs
  WHERE service_name IS DISTINCT FROM 'local'")"
[[ "$external_blobs" == 0 ]] ||
  die "Some Active Storage blobs reference non-local or unknown services."

connections="$(query "$EXPECTED_DB" "SELECT count(*) FROM pg_stat_activity
  WHERE datname=current_database() AND pid <> pg_backend_pid()")"
[[ "$connections" == 0 ]] ||
  die "$connections additional DB sessions exist. Stop writers and retry."
can_create="$(query "$EXPECTED_DB" "SELECT CASE WHEN rolcreatedb OR rolsuper
  THEN 'yes' ELSE 'no' END FROM pg_roles WHERE rolname=current_user")"
[[ "$can_create" == yes ]] || die "Local role cannot create an isolated scratch database."

db_bytes="$(query "$EXPECTED_DB" "SELECT pg_database_size(current_database())")"
media_bytes="$(du -sb "$ROOT/storage" | awk '{print $1}')"
[[ "$db_bytes" =~ ^[0-9]+$ && "$media_bytes" =~ ^[0-9]+$ ]] ||
  die "Cannot safely calculate backup sizes."

# Ensure private archive ancestors are not symlinks or group/world writable.
# Creating only the OWNER'S backup directory is allowed *after* all consent gates.
for segment in "$HOME" "$HOME/.local" "$HOME/.local/share" \
               "$HOME/.local/share/rails-calendar" "$BACKUP_ROOT"; do
  [[ ! -L "$segment" ]] || die "Backup path contains a symlink."
  if [[ -e "$segment" ]]; then
    [[ -d "$segment" && "$(stat -c '%U' "$segment")" == "$EXPECTED_ROLE" ]] ||
      die "Backup path is not an owner-controlled directory."
    mode="$(stat -c '%a' "$segment")"
    [[ "$mode" =~ ^[0-7]{3,4}$ ]] || die "Unsafe backup path mode."
    (( (8#$mode & 0022) == 0 )) ||
      die "Backup ancestor is writable by group/others."
  fi
done

# Filesystem capacity check intentionally over-reserves 4x PG DB + 3x media
# plus 2 GiB for dump, extracted media, DB restore and temporary indexes.
# The user's disk was 92% full with ~23 GB free at last observation.
free_bytes="$(df -B1 --output=avail "$HOME" | awk 'END {print $1}')"
required_bytes="$((4 * db_bytes + 3 * media_bytes + 2147483648))"
[[ "$free_bytes" =~ ^[0-9]+$ && "$free_bytes" -ge "$required_bytes" ]] ||
  die "Insufficient free space for dump + scratch restore; no archive created."
printf 'Pre-write checks PASS: PG16 local review DB, stopped sessions, media and disk budget.\n'

mkdir -p -m 700 -- "$BACKUP_ROOT"
[[ -d "$BACKUP_ROOT" && ! -L "$BACKUP_ROOT" &&
   "$(stat -c '%U' "$BACKUP_ROOT")" == "$EXPECTED_ROLE" &&
   "$(stat -c '%a' "$BACKUP_ROOT")" == 700 ]] ||
  die "Backup directory is not private mode 0700."
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
backup="$(mktemp -d "$BACKUP_ROOT/r04_${stamp}_XXXXXXXX")"
[[ -d "$backup" && ! -L "$backup" &&
   "$(stat -c '%a' "$backup")" == 700 ]] ||
  die "Private backup session directory unavailable."

# A separate custom-format dump. A failed dump is preserved for inspection.
PGOPTIONS='' "$PG_BIN/pg_dump" -w -Fc --no-owner --no-acl \
  -h "$SOCKET" -p "$PORT" -U "$EXPECTED_ROLE" \
  -f "$backup/review.pgcustom" "$EXPECTED_DB"
"$PG_BIN/pg_restore" -l "$backup/review.pgcustom" >/dev/null ||
  die "PG custom archive cannot be inspected."
tar -C "$ROOT" -cf "$backup/storage.tar" -- storage
tar -tf "$backup/storage.tar" >/dev/null || die "Storage archive unreadable."
(
  cd "$backup"
  sha256sum review.pgcustom storage.tar > SHA256SUMS
  sha256sum -c SHA256SUMS >/dev/null
)

mkdir -m 700 "$backup/media_restore"
tar -xf "$backup/storage.tar" -C "$backup/media_restore" \
  --no-same-owner --no-same-permissions
diff -qr "$ROOT/storage" "$backup/media_restore/storage" \
  >"$backup/media_comparison_private.txt" 2>&1 ||
  die "Isolated media comparison failed; details kept in private backup."

scratch="rails_calendar_r04_restore_${stamp}_$RANDOM"
[[ "$scratch" != "$EXPECTED_DB" && "$scratch" =~ ^[a-z0-9_]+$ &&
   "${#scratch}" -le 63 ]] || die "Unsafe scratch database name."
[[ "$(query "$EXPECTED_DB" "SELECT count(*) FROM pg_database WHERE datname='$scratch'")" == 0 ]] ||
  die "Scratch collision; preserving archive."
PGOPTIONS='' "$PG_BIN/createdb" -w -h "$SOCKET" -p "$PORT" \
  -U "$EXPECTED_ROLE" -T template0 "$scratch"
printf 'Created isolated scratch DB. Source database untouched by restore.\n'
PGOPTIONS='' "$PG_BIN/pg_restore" -w --exit-on-error --no-owner --no-acl \
  -h "$SOCKET" -p "$PORT" -U "$EXPECTED_ROLE" -d "$scratch" \
  "$backup/review.pgcustom"

source_tables="$(query "$EXPECTED_DB" "SELECT count(*) FROM pg_tables WHERE schemaname='public'")"
scratch_tables="$(query "$scratch" "SELECT count(*) FROM pg_tables WHERE schemaname='public'")"
[[ "$source_tables" == "$scratch_tables" ]] ||
  die "Source/scratch schema table totals differ; retain restore for review."
printf 'table\tsource\trestored\n' > "$backup/row_counts_private.tsv"
for table in users workspaces project_intakes schema_migrations \
             active_storage_blobs active_storage_attachments; do
  source_count="$(query "$EXPECTED_DB" "SELECT count(*) FROM public.$table")"
  scratch_count="$(query "$scratch" "SELECT count(*) FROM public.$table")"
  printf '%s\t%s\t%s\n' "$table" "$source_count" "$scratch_count" \
    >> "$backup/row_counts_private.tsv"
  [[ "$source_count" == "$scratch_count" ]] ||
    die "Source/scratch row totals differ: $table; retain restore for review."
done
src_versions="$(query "$EXPECTED_DB" "SELECT coalesce(string_agg(version, ',' ORDER BY version), '')
  FROM public.schema_migrations")"
dst_versions="$(query "$scratch" "SELECT coalesce(string_agg(version, ',' ORDER BY version), '')
  FROM public.schema_migrations")"
[[ "$src_versions" == "$dst_versions" ]] ||
  die "schema_migrations differ; retain restore for review."

remaining="$(query "$EXPECTED_DB" "SELECT count(*) FROM pg_stat_activity
  WHERE datname=current_database() AND pid <> pg_backend_pid()")"
[[ "$remaining" == 0 ]] ||
  die "A source DB connection appeared; inspect consistency before migration."
( cd "$backup" && sha256sum -c SHA256SUMS >/dev/null ) ||
  die "Archive checksum changed after restore."
{
  printf 'source_db=%s\nscratch_db=%s\n' "$EXPECTED_DB" "$scratch"
  printf 'source_pg_major=16\nlocal_unix_socket=yes\n'
  printf 'source_tables=%s\nscratch_tables=%s\n' "$source_tables" "$scratch_tables"
  printf 'db_archive_sha256_and_media_sha256=verified\n'
  printf 'media_extracted_byte_comparison=verified\n'
  printf 'schema_versions_and_core_table_counts=matched\n'
  printf 'backup_created_utc=%s\n' "$stamp"
  printf 'backup_and_scratch_preserved=yes\n'
} > "$backup/verification_private.txt"
printf 'PASS R0.4b: private custom PG archive, local media, SHA256 and scratch restore verified.\n'
printf 'Source DB/storage not modified by this script. Private backup and scratch DB PRESERVED.\n'
printf 'No automatic migration, no cleanup, no Railway and no paid AI call.\n'
printf 'Never upload private backup content, files or logs to chat/GitHub/cloud storage.\n'
