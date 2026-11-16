#!/usr/bin/env bash
# Offline deny-path tests only. NEVER connect to real DB or create a backup in CI.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/script/rc0551f_c21_backup_and_verify.sh"
bash -n "$SCRIPT"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT

if env -u DATABASE_URL -u RC_CONFIRM_WRITERS_STOPPED -u RC_CONFIRM_ISOLATED_RESTORE RAILS_ENV=development bash "$SCRIPT" >"$tmp/unconfirmed" 2>&1; then
  echo 'FAIL: archive must require explicit app/writer stop confirmation' >&2
  exit 1
fi
grep -Fq 'RC_CONFIRM_WRITERS_STOPPED=YES' "$tmp/unconfirmed"

if env -u DATABASE_URL -u RC_CONFIRM_ISOLATED_RESTORE RAILS_ENV=development RC_CONFIRM_WRITERS_STOPPED=YES bash "$SCRIPT" >"$tmp/restore" 2>&1; then
  echo 'FAIL: archive must require isolated restore confirmation' >&2
  exit 1
fi
grep -Fq 'RC_CONFIRM_ISOLATED_RESTORE=YES' "$tmp/restore"

if env RAILS_ENV=production RC_CONFIRM_WRITERS_STOPPED=YES RC_CONFIRM_ISOLATED_RESTORE=YES bash "$SCRIPT" >"$tmp/production" 2>&1; then
  echo 'FAIL: production access accepted' >&2
  exit 1
fi
grep -Fq 'Only local development preview is allowed' "$tmp/production"

if env -u RAILS_ENV DATABASE_URL='postgresql://invalid.example/production' RC_CONFIRM_WRITERS_STOPPED=YES RC_CONFIRM_ISOLATED_RESTORE=YES bash "$SCRIPT" >"$tmp/database_url" 2>&1; then
  echo 'FAIL: inherited external DATABASE_URL accepted' >&2
  exit 1
fi
grep -Fq 'DATABASE_URL is set' "$tmp/database_url"

# Structural invariants for this small operator tool.
grep -Fq 'pg_dump -w -Fc' "$SCRIPT"
grep -Fq 'pg_restore -w --exit-on-error --no-owner --no-acl' "$SCRIPT"
grep -Fq 'diff -qr "$ROOT/storage" "$backup/restored_storage/storage"' "$SCRIPT"
grep -Fq 'sha256sum -c SHA256SUMS' "$SCRIPT"
grep -Fq 'createdb -w -h "$SOCKET" -p "$PORT" -U "$ROLE" -T template0 "$restore_db"' "$SCRIPT"
if grep -Eq '(^|[[:space:]])(dropdb|rm[[:space:]]+-rf[[:space:]]+["$]|db:reset|db:drop|--clean)' "$SCRIPT"; then
  echo 'FAIL: destructive database/file action in archive script' >&2
  exit 1
fi
echo 'RC055.1f C2.1 backup-and-isolated-restore offline guards: PASS'
