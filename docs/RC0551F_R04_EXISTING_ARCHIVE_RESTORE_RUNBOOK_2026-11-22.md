# R0.4b2 — resume existing archive to isolated scratch, 2026-11-22

STATUS: CODE PREPARED / CI PENDING / NO USER-LOCAL RESTORE YET.

## Evidence
- Owner terminal local `READ_ONLY_PREFLIGHT=PASS`: HEAD c25be48, `M db/schema.rb`, old writer untracked; exact local PG16.11 socket review DB `rails_calendar_rc0551f_c21b_review_20261117`, role gor, OTHER_SESSIONS=0, OUTBOX=false, 23 GB free.
- Previously independently inspected private r04_* session with SHA256 PASS, readable PG custom archive and tar, scratch prefix count 0; backup stays private local.

## Recovery contract
- This is a NEW resume-only script, not the old immutable backup writer. Use EXISTING review.pgcustom/storage.tar/media_restore only. No pg_dump, file extraction, DB migrations, cleanup, dropdb, source DB changes, paid AI or Railway operations.
- Fail closed on wrong user/worktree, RAILS_ENV, DATABASE_URL, missing confirmation, PG16/socket mismatch, other source sessions, port 3002 listener, changed media, bad checksum, non-private directory, multiple backup sessions, name collision, disk shortage. Require user input `RESTORE-EXISTING-ARCHIVE` in an interactive TTY immediately before first write.
- Create only a NEW lower-case UTC-named scratch via createdb -T template0, restore using pg_restore --exit-on-error --no-owner --no-acl. Check public table lists, six core table counts, schema_migrations and SHA256. Preserve archive and scratch on any failure; do not retry or delete automatically.
- CI runs only Bash syntax and offline deny-path/structural tests, NEVER connects to user's PG or private archive. CI green ≠ real scratch restore acceptance.

## User-local operator gate (separate explicit approval required)
1. Verify exact branch SHA plus exact-SHA Rails CI and Security Audit. Fetch ONLY new script from pinned Git object; bash -n, compare Git blob SHA, preserve modified db/schema.rb and old local writer, no blind git pull.
2. Repeat read-only PG16 review DB, media/permissions, process and disk checks. If state changed STOP.
3. With explicit permission, provide all four RC_CONFIRM_* inputs and interactive RESTORE-EXISTING-ARCHIVE. On PASS record scratch name and table counts (never private rows, credentials or file contents). Next independently rehearse only migration 20261121003000 on scratch after separate authorization.

Canonical status: docs/RAILS_CALENDAR_EXECUTION_STATUS.md; Draft PR #81. No production merge/deploy permission.
