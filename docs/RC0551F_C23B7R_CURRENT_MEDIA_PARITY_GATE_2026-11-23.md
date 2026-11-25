# C2.3b7r — current Active Storage files vs historical R0.4 extracted copy (PROPOSAL ONLY)

**2026-11-23 — Draft PR #81. OFFLINE DESIGN. No new permission for media-byte reads. Not executed.**

## Evidence already verified

- Owner C2.3b7p OS-metadata-only preflight PASS: exactly one private R0.4 session and named PostgreSQL/media archives/manifest are owner-only; `media_restore/storage` directory exists. A port 3001/3002 / short-process inspection found no matches at one instant, not full G6 writer quiescence.
- Owner C2.3b7q SINGLE approved archive-byte read PASS: two strict entries in existing `SHA256SUMS`; `review.pgcustom` and `storage.tar` hashes matched manifest; `pg_restore --list` and `tar --list` completed successfully with private output suppressed. `SOURCE_OR_DB_QUERIES=NOT_PERFORMED`, `NO_MUTATIONS=TRUE`. **C2.3b7q approval CONSUMED; do not repeat.**
- Previously authorized R0.4b2 restoration on **2026-11-22** already included a media tar extraction to a private directory and a then-current `diff -qr` comparison with source `storage/`. That is *historical* snapshot evidence and is NOT a current byte comparison. See [R0.4b2 runbook](RC0551F_R04_EXISTING_ARCHIVE_RESTORE_RUNBOOK_2026-11-22.md) and its [exact operator](../script/rc0551f_r04_resume_existing_archive_restore.sh).
- C2.3b7n minimum 17-table scratch metadata contract PASS. Full G5, tenant ACL/lineage, current source/cohort and backup restore parity are NOT fully accepted.

## Proposed next one-shot operation (separate owner approval REQUIRED)

**Purpose:** assess *current* local Active Storage file-tree parity with the restored-media copy inside the single historical owner-private R0.4 backup session. This is distinct from verifying archive hash/format, and reads private media bytes. The owner must separately authorize it; generic 'continue' and prior C2.3b7q archive-read consent do not transfer.

Exact paths: source tree `~/rails_calendar_ai_c21c/storage` (owner's existing local checkout, whose modified `db/schema.rb` must be preserved); comparison tree `~/.local/share/rails-calendar/review-backups-r04/<single r04_* session>/media_restore/storage`. Both must have real canonical directories, no symlink root, no nested symlinks, no nonregular entries; owner `gor` and no unexpected path escapes or permission drift. Fail on any unexpected tree structure.

Offline operator design must use strictly read-only filesystem operations and a finite timeout, never rename, extract, backup, remove, chmod, migrate, write SQL or boot Rails. For *identical source and restored file paths and contents* return `C23B7R_CURRENT_MEDIA_VS_R04_SNAPSHOT=MATCH`; for a well-formed but different tree return `...=DELTA_REVIEW`, and for invalid configuration/timeouts `...=BLOCKED`. Suppress `diff` names, private paths, file contents and checksums. No traversal into arbitrary external symlinks or device files. No automatic rerun.

**Interpretation:** MATCH means only current file-tree bytes on that host matched the R0.4 extracted snapshot at the observed instant. DELTA_REVIEW is not proof of corruption; legitimate additions, deletes or uploads after snapshot may explain it. Neither result proves that DB Active Storage attachment references are valid, matches source/scratch DB snapshots/tenants, or confirms a recoverable modern backup. Those need separately authorized, minimal-PII, snapshot-aligned validations. If active writers/uploads/storage changes cannot be excluded, STOP and do not declare durable parity.

**Prerequisite for a runnable command:** independently recheck exact PR SHA, CI, local path identity and permissions; record a fresh explicit owner consent for **ONE current local media-byte read/comparison**. Preserve source, historical extracted copy, archives, all review/scratch DBs, dirty schema, worktrees and Railway. Use only redacted PASS/DELTA_REVIEW/BLOCKED flags. No raw outputs to GitHub/Drive/Notion/ClickUp.

## Gate progression

`C2.3b7q ARCHIVE_SHA256_AND_FORMAT=PASS` (owner terminal); `C2.3b7r CURRENT_MEDIA_COMPARISON=NOT_AUTHORIZED_NOT_EXECUTED`; `G3 HISTORICAL_ARCHIVE_CURRENT_CHECKSUM=PASS` (manifest authenticity not independently proved); `G4 FULL=OPEN` (historical restore confirmed, current complete cohort and file references not); `G5 MIN_17_TABLE_CATALOG=PASS`, `G5 FULL=BLOCKED`; `G6 WRITER_QUIESCENCE=NOT_VERIFIED`; `G7 SOURCE_ROW_SCAN=NOT_AUTHORIZED`; `WRITES_REPLAY_PRODUCTION=NOT_AUTHORIZED`.