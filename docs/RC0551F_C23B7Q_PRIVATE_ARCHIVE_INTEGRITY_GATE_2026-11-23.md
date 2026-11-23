# C2.3b7q — current integrity of existing private PostgreSQL+media archives (PROPOSED ONLY)

**Date: 2026-11-23 · Draft PR #81 · OFFLINE DESIGN / NOT AUTHORIZED / NOT EXECUTED.**

## Trigger and observed state

C2.3b7p returned `C23B7P_METADATA_PREFLIGHT=PASS`, private backup container and three named files owner-only-present, extracted historical media directory present. `G6_PORTS_3001_3002=NONE_OBSERVED`, `G6_RAILS_PROCESS_SIGNATURES=NONE_OBSERVED`, but `G6_WRITER_QUIESCENCE=NOT_VERIFIED`. No archive bytes read or mutations performed by C2.3b7p. Prior C2.3b7n 17-table *minimum* catalog PASS remains limited; its one-shot DB permission was consumed. See [current ledger](RAILS_CALENDAR_EXECUTION_STATUS.md).

Prior [R0.4b2 restore runbook](RC0551F_R04_EXISTING_ARCHIVE_RESTORE_RUNBOOK_2026-11-22.md) documented owner-verified 2026-11-22 archive SHA-256 and isolated scratch restore of a historical snapshot; do not repeat that restore or infer current backup integrity from an old check. [C2.3b7h rehearsal SOP](RC0551F_C23B7H_OPERATOR_REHEARSAL_RUNBOOK_2026-11-22.md) keeps G3/G4/G6 separate.

## Exact scope of the proposed future SINGLE owner-local check

**Prerequisite:** separately obtain an affirmative, fresh, scope-specific owner authorization to **read** the existing private archive bytes for this integrity check. The user's generic request to continue does **not** authorize it. Do not provide or execute a runnable archive-byte-reading operator until that permission is recorded.

1. Read-only, fail-closed verification on the owner Linux Mint OS under local user `gor`. Only canonical pre-existing private R0.4 backup root and exactly ONE owner-owned, mode-0700 session; no symlinks in the known path or special files, archive/manifest modes owner-only. No stdout of private paths, session identifiers, manifest text or archive filenames beyond the public fixed allowlist.
2. Validate a strict two-line SHA256SUMS manifest: exactly lowercase 64-hex digest followed by exactly `review.pgcustom` or `storage.tar`, each once, no other records. Do not print hash values. Compare the local contents of **only** these two owner-private files against their corresponding manifest digests with GNU sha256sum check privately. An archive hash match proves no drift relative to the stored manifest; it does not independently authenticate when/by whom the manifest was created.
3. Independently validate **archive-format readability**, no extraction: `pg_restore --list` for the existing custom-format PostgreSQL archive with stdout and stderr discarded, and tar listing for the existing media tar with stdout/stderr discarded. Do not print TOC, SQL, tar entry names, blob paths or file contents. Both must finish successfully within reviewed local resource/time limits.
4. Output only fixed labels: `C23B7Q_PRIVATE_ARCHIVE_INTEGRITY=PASS|BLOCKED`, `G3_ARCHIVE_SHA256=PASS|BLOCKED`, `G3_PGCUSTOM_PARSE=PASS|BLOCKED`, `G3_MEDIA_TAR_PARSE=PASS|BLOCKED`, `G4_CURRENT_MEDIA_BYTES=NOT_COMPARED`, `G6_WRITER_QUIESCENCE=NOT_VERIFIED`, `SOURCE_OR_DB_QUERIES=NOT_PERFORMED`, `NO_MUTATIONS=TRUE`. Fail closed on missing/ambiguous session, ACL/ownership drift, unsupported archive, incomplete verification or timeout; do not auto-retry and do not output raw tool errors.

## Non-goals and safety separation

- No new `pg_dump` or backup, no `pg_restore -d`, no `createdb`, no SQL, no live DB reads or mutations, no tar extraction, no filesystem cleanup or permission changes.
- Do not touch any project checkout or modified `db/schema.rb`, the source/review DB, the historical scratch DB, Active Storage source/media bytes, Railway or production.
- Never upload any private archive, SHA256 manifest, extracted filenames, blob keys, PII, credentials or raw media to GitHub, Drive, Notion, ClickUp or an AI model.
- No automatic second pass. If the integrity check fails, report only bounded status and require manual review; never attempt repairs.
- `G3` present-archive hash/format PASS, if ultimately observed, would still **not** clear `G4` restore/current source/media parity, full `G5` types/tenancy, `G6` actual writer isolation or `G7` approval for six-family row scans. Those must follow independently with explicit owner permission.

## Current decision

`PLAN_PREPARED=TRUE`, `OWNER_APPROVAL=NOT_RECEIVED`, `PRIVATE_ARCHIVE_BYTES_NOT_ACCESSED=TRUE`, `G3_CURRENT_SHA256=NOT_RECHECKED`, `G4_CURRENT_PARITY=NOT_VERIFIED`, `G5_FULL=BLOCKED`, `G6=NOT_VERIFIED`, `G7=NOT_AUTHORIZED`. Next step: request owner opt-in for the exactly scoped one-shot read-only archive integrity check after verifying exact current PR and SHA/CI. No executable command is included here.