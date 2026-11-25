# C2.3b7p — private backup metadata / local process inventory: non-invasive preflight

**Date: 2026-11-23 | Draft PR #81 | owner-terminal action NOT YET EXECUTED.** This read-only local check is a narrow next action for G3/G4/G6 after C2.3b7n 17-table minimum catalog PASS. It is NOT a restore, backup-verification hash, media comparison, PostgreSQL operation, tenant scan, replay, or G6 full writer-quiescence attestation.

## Evidence carried forward

- The prior **R0.4b2** session's owner-terminal backup archive, private media tar and historical scratch restore were already independently tested for the 2026-11-22 snapshot. This preflight does NOT redo that restore.
- Existing [R0.4 archive restore runbook](RC0551F_R04_EXISTING_ARCHIVE_RESTORE_RUNBOOK_2026-11-22.md) and immutable operator define the `r04_*` private backup layout: one owner-private session, `review.pgcustom`, `storage.tar`, `SHA256SUMS`, and `media_restore/storage`.
- C2.3b7n's single permitted metadata query returned `C2.3B7N_17_TABLE_CATALOG=PASS`; b7j/k/l/n query authorizations are **CONSUMED**. This command makes **no SQL connection**.
- All four exact-SHA Rails CI + Security runs for prior docs/head `c9949f5c7770137f7d65d694d88c89e28b80e418` completed **SUCCESS** (PR Rails #45091252217, PR Security #45091252316, push Rails #45091245070, push Security #45091245051). This docs change will need its own checks.

## Read surface and fail-closed behavior

Only `id`, `stat` and shell existence/symlink checks on **known directory entries**, plus `ss` on the two previously checked local app ports and `ps` on gor-owned short process names. It does **not** open, hash, list archive contents, traverse storage or access media file bytes; does **not** query PostgreSQL, inspect `pg_stat_activity`, read Rails configuration or change filesystem/permissions. It prints strictly allowlisted status labels, never archive/session names, paths, PIDs, usernames from other accounts, process argv, client IDs, tokens, checksums or raw values.

STOP on ambiguous/missing backup session, unexpected symlink, ownership or owner-only permissions. A STOP is no permission to fix permissions, delete, rename or rerun. Signals from ports or process names are **only hints**: even when no listener or matching process is observed, other writers may be active. G3 actual digest verification and G4 private source/scratch/media byte parity remain NOT RECHECKED. No action on Railway.

## Operator's ONE next step (direct owner terminal, no repo changes required)

Do not add this command to CI or GitHub Actions. Run once from any shell on the owner Linux Mint machine. It does not depend on the current dirty checkout.

```bash
bash <<'BASH'
set -euo pipefail
umask 077
stop() { printf 'C23B7P_STOP=%s\n' "$1"; exit 2; }

[[ "$(id -un)" == "gor" ]] || stop OS_USER
base="$HOME/.local/share/rails-calendar/review-backups-r04"
for d in "$HOME/.local" "$HOME/.local/share" "$HOME/.local/share/rails-calendar" "$base"; do
  [[ -d "$d" && ! -L "$d" ]] || stop PRIVATE_PATH_TYPE
  [[ "$(stat -c '%U' -- "$d")" == "gor" ]] || stop PRIVATE_PATH_OWNER
done
[[ "$(stat -c '%a' -- "$base")" == "700" ]] || stop BACKUP_ROOT_MODE

shopt -s nullglob
sessions=("$base"/r04_*)
((${#sessions[@]} == 1)) || stop BACKUP_SESSION_COUNT
session="${sessions[0]}"
[[ -d "$session" && ! -L "$session" ]] || stop BACKUP_SESSION_TYPE
[[ "$(stat -c '%U:%a' -- "$session")" == "gor:700" ]] || stop BACKUP_SESSION_PERMISSIONS

for name in review.pgcustom storage.tar SHA256SUMS; do
  file="$session/$name"
  [[ -f "$file" && ! -L "$file" ]] || stop BACKUP_FILE_TYPE
  [[ "$(stat -c '%U' -- "$file")" == "gor" ]] || stop BACKUP_FILE_OWNER
  mode="$(stat -c '%a' -- "$file")"
  [[ "$mode" =~ ^[0-7]{3,4}$ ]] || stop BACKUP_FILE_MODE
  (( (8#$mode & 077) == 0 )) || stop BACKUP_FILE_PUBLIC_PERMISSIONS
done

for d in "$session/media_restore" "$session/media_restore/storage"; do
  [[ -d "$d" && ! -L "$d" ]] || stop RESTORED_MEDIA_TYPE
  [[ "$(stat -c '%U' -- "$d")" == "gor" ]] || stop RESTORED_MEDIA_OWNER
done

listeners="$(ss -H -ltn '( sport = :3001 or sport = :3002 )')" || stop SOCKET_INVENTORY
processes="$(ps -u gor -o comm=)" || stop PROCESS_INVENTORY

printf '%s\n' 'C23B7P_METADATA_PREFLIGHT=PASS' 'G3_PRIVATE_BACKUP_CONTAINER=OWNER_ONLY_PRESENT' 'G3_ARCHIVE_FILES=OWNER_ONLY_PRESENT' 'G3_ARCHIVE_HASHES=NOT_RECHECKED' 'G4_RESTORED_MEDIA_PATH=METADATA_PRESENT' 'G4_CONTENT_AND_SOURCE_PARITY=NOT_VERIFIED'

if [[ -n "$listeners" ]]; then
  echo 'G6_PORTS_3001_3002=LISTENERS_OBSERVED'
else
  echo 'G6_PORTS_3001_3002=NONE_OBSERVED'
fi
if grep -Eq '^(ruby|rails|puma|sidekiq|solid_queue|resque|delayed_job)$' <<< "$processes"; then
  echo 'G6_RAILS_PROCESS_SIGNATURES=OBSERVED'
else
  echo 'G6_RAILS_PROCESS_SIGNATURES=NONE_OBSERVED'
fi

printf '%s\n' 'G6_WRITER_QUIESCENCE=NOT_VERIFIED' 'G5_FULL=BLOCKED' 'NO_DATABASE_OR_BACKUP_BYTES_READ=TRUE' 'NO_MUTATIONS=TRUE'
BASH
```

## Evidence classification (PENDING owner output)

- `C23B7P_METADATA_PREFLIGHT=PASS` means **only** that the guarded metadata existence/ownership/read-mode checks passed and process/listener statuses were observed at that instant.
- `G3_ARCHIVE_HASHES=NOT_RECHECKED` means no SHA-256 or file integrity assurance today; earlier R0.4b2 historical evidence is preserved.
- `G4_CONTENT_AND_SOURCE_PARITY=NOT_VERIFIED` means the extracted directory path exists but no bytes or DB rows were compared.
- `G6_WRITER_QUIESCENCE=NOT_VERIFIED` means actual reader/writer quiescence, session isolation and tenant ACL still require separately reviewed evidence.
- `G5_FULL=BLOCKED` and G7 read-only historical scan/replay NOT AUTHORIZED, regardless of preflight output.

**On owner result:** update `docs/RAILS_CALENDAR_EXECUTION_STATUS.md` and PR #81 with only the sanitized flags and exact stage; do not treat any private metadata from the terminal as something automatically uploaded to the repo. Future archive hash/media read or database query is a different scope needing explicit independent owner approval. Do not reset, clear or migrate any existing DB or worktree.