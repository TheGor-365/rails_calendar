#!/usr/bin/env bash
# RC055.1f C2.1 — NEW LOCAL preview backup + isolated restore.
# Do not call on Railway/production. Creates a separate scratch DB; never drops it.
set -euo pipefail
umask 077

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
DB="rails_calendar_mvp_preview_20261112"
ROLE="${RC_BACKUP_DB_USER:-$(id -un)}"
SOCKET="/var/run/postgresql"
PORT=5432
PORT_APP=3012

die() { printf 'STOP: %s\n' "$1" >&2; exit 1; }
[[ "${RAILS_ENV:-development}" == development ]] || die "Only local development preview is allowed."
[[ -z "${DATABASE_URL:-}" ]] || die "DATABASE_URL is set. Refusing a potentially remote database."
[[ "${RC_CONFIRM_WRITERS_STOPPED:-}" == YES ]] || die "Stop preview Rails AND all workers, then explicitly set RC_CONFIRM_WRITERS_STOPPED=YES."
[[ "${RC_CONFIRM_ISOLATED_RESTORE:-}" == YES ]] || die "You must explicitly confirm creation of a NEW scratch restore DB with RC_CONFIRM_ISOLATED_RESTORE=YES."

for cmd in ss pg_dump pg_restore psql createdb tar sha256sum diff df du stat date mktemp find awk; do
  command -v "$cmd" >/dev/null || die "Missing required command: $cmd"
done
[[ -S "$SOCKET/.s.PGSQL.$PORT" ]] || die "Local PostgreSQL socket not found."
[[ -d "$ROOT/storage" && ! -L "$ROOT/storage" ]] || die "Private storage directory missing or symlinked."
[[ "$(find "$ROOT/storage" -type l | wc -l)" == 0 ]] || die "Storage contains symlinks."
[[ "$(find "$ROOT/storage" ! -type d ! -type f | wc -l)" == 0 ]] || die "Storage contains unusual file types; inspect manually."

if ss -H -ltn "sport = :$PORT_APP" | grep -q .; then
  die "Preview TCP port $PORT_APP is LISTENING. Stop the Rails preview server first."
fi

bash "$ROOT/script/rc0551f_c21_backup_preflight.sh"

read_query() {
  PGOPTIONS='-c default_transaction_read_only=on' \
    psql -X -w -h "$SOCKET" -p "$PORT" -U "$ROLE" -d "$1" \
    -v ON_ERROR_STOP=1 -Atc "$2"
}
others="$(read_query "$DB" "SELECT count(*) FROM pg_stat_activity WHERE datname = current_database() AND pid <> pg_backend_pid()")"
[[ "$others" == 0 ]] || die "$others other preview DB sessions remain; stop app/workers."

can_create="$(read_query "$DB" "SELECT CASE WHEN rolcreatedb OR rolsuper THEN 'yes' ELSE 'no' END FROM pg_roles WHERE rolname=current_user")"
[[ "$can_create" == yes ]] || die "DB role lacks CREATEDB privilege for isolated restore; no backup created."

backup_root="${RC_BACKUP_ROOT:-$HOME/.local/share/rails-calendar/backups}"
[[ ! -L "$backup_root" ]] || die "Backup root is a symlink."
mkdir -p -m 700 -- "$backup_root"
[[ -d "$backup_root" && ! -L "$backup_root" ]] || die "Unsafe backup root."
chmod 700 -- "$backup_root"

db_bytes="$(read_query "$DB" "SELECT pg_database_size(current_database())")"
storage_bytes="$(du -sb "$ROOT/storage" | awk '{print $1}')"
free_bytes="$(df -B1 --output=avail "$backup_root" | awk 'END {print $1}')"
required_bytes="$((4 * db_bytes + 3 * storage_bytes + 268435456))"
[[ "$free_bytes" -ge "$required_bytes" ]] || die "Not enough free space for dump, media, and isolated restore."

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
backup="$(mktemp -d "$backup_root/rc0551f_c21_{stamp}_XXXXXXXX")"
chmod 700 "$backup"
restore_db="rails_calendar_rc0551f_c21_restore_{stamp}_$RANDOM"
printf 'Backup directory created under owner-private local backups.\n'

pg_dump -w -Fc --no-owner --no-acl \
  -h "$SOCKET" -p "$PORT" -U "$ROLE" -f "$backup/preview.pgcustom" "$DB"
pg_restore -l "$backup/preview.pgcustom" >/dev/null || die "Archive validation failed; source unchanged."

tar -C "$ROOT" -cf "$backup/storage.tar" -- storage
tar -tf "$backup/storage.tar" >/dev/null || die "Storage archive validation failed."
(
  cd "$backup"
  sha256sum preview.pgcustom storage.tar > SHA256SUMS
  sha256sum -c SHA256SUMS >/dev/null
)
printf 'PASS: private PG archive, storage tar and checksums.\n'

mkdir -m 700 "$backup/restored_storage"
tar -xf "$backup/storage.tar" -C "$backup/restored_storage" --no-same-owner --no-same-permissions
if ! diff -qr "$ROOT/storage" "$backup/restored_storage/storage" > "$backup/storage_diff_private.txt" 2>&1; then
  die "Isolated media comparison FAILED; private details kept in backup directory."
fi
printf 'PASS: isolated private media extraction and byte comparison.\n'

if read_query "$DB" "SELECT 1 FROM pg_database WHERE datname = '$restore_db'" | grep -q .; then
  die "Scratch DB name collision. Backup preserved; no restore performed."
fi
createdb -w -h "$SOCKET" -p "$PORT" -U "$ROLE" -T template0 "$restore_db"
printf 'Created new isolated scratch database; preview unchanged.\n'
pg_restore -w --exit-on-error --no-owner --no-acl \
  -h "$SOCKET" -p "$PORT" -U "$ROLE" -d "$restore_db" "$backup/preview.pgcustom"

tables=(
  users workspaces professional_profiles project_intakes
  service_offerings service_offering_versions ai_spend_entries
  active_storage_blobs active_storage_attachments
)
printf 'table\tsource\trestored\n' > "$backup/row_counts_private.tsv"
for table in "${tables[@]}"; do
  src="$(read_query "$DB" "SELECT count(*) FROM public.$table")"
  dst="$(read_query "$restore_db" "SELECT count(*) FROM public.$table")"
  printf '%s\t%s\t%s\n' "$table" "$src" "$dst" >> "$backup/row_counts_private.tsv"
  [[ "$src" == "$dst" ]] || die "Restore count mismatch in $table; preserve both DBs."
done

others="$(read_query "$DB" "SELECT count(*) FROM pg_stat_activity WHERE datname=current_database() AND pid <> pg_backend_pid()")"
[[ "$others" == 0 ]] || die "A preview DB session appeared mid-backup; repeat a new consistent snapshot."

{
  printf 'created_utc=%s\nsource_db=%s\nserver=local-pg16-socket\n' "$stamp" "$DB"
  printf 'restore_db=%s\n' "$restore_db"
  printf 'pg_custom=preview.pgcustom\nprivate_media=storage.tar\n'
  printf 'schema_and_counts_verified=yes\nprivate_media_verified=yes\n'
  printf 'archive_sha256=SHA256SUMS\n'
  printf 'notes=Owner-only files and scratch DB; decryption keys are separate.\n'
} > "$backup/verification.txt"
( cd "$backup" && sha256sum -c SHA256SUMS >/dev/null )
printf 'PASS: isolated database RESTORE and all %s critical table counts.\n' "${#tables[@]}"
printf 'PASS: MEDIA ARCHIVE, EXTRACTED FILES, CHECKSUMS and SOURCE/RESTORE CHECKS.\n'
printf 'Private backup and isolated scratch DB PRESERVED. No cleanup performed.\n'
printf 'Original preview DB and storage were not written by this script.\n'
printf 'Do NOT upload backup files or private contents to a chat/cloud repository.\n'
