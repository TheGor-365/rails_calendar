# RC055.1f C2.1a — guarded scratch-only migration gate
Date: 2026-11-17 · Parent: [Draft PR #76](https://github.com/TheGor-365/rails_calendar/pull/76).
State: proposed owner-only conversation schema and guarded operator command, **NOT executed on any local DB**. Production and original preview remain unchanged.

## Verified prerequisite — user terminal
- Private backup-and-verify script returned both final PASS markers: original PG16.11 preview database was archived, all 11 private storage files archived with SHA-256 and bytewise extracted compare, and the restored PostgreSQL scratch copy matched the nine critical table counts.
- User checked out C2.1a branch at `97d24f4`, clean, and used a **read-only** SQL query to identify exactly one scratch database: `rails_calendar_rc0551f_c21_restore_20261116T224810Z_7877`.
- The original preview remains `rails_calendar_mvp_preview_20261112`. **Never replace either name with a guessed value**; nothing has yet migrated the restored scratch copy.

## What to run / what must not happen
`script/rc0551f_c21a_migrate_scratch_only.sh` is a fail-closed, one-migration operator script:
1. Requires local PG16 binaries, user `gor`, Unix socket `/var/run/postgresql`, that **exact scratch DB name**, restored `workspaces`, `ai_spend_entries`, `schema_migrations` and **both Active Storage tables**, and verifies that the two owner AI tables do not exist. Rejects RAILS_ENV other than development and any preexisting generic `DATABASE_URL`.
2. Prints preflight PASS but refuses all writes unless the owner explicitly starts it with `RC_CONFIRM_SCRATCH_MIGRATION=YES`.
3. Overrides only the development connection with `RC_LOCAL_DEV_DATABASE_URL=postgresql://gor@localhost/<exact scratch DB>?host=%2Fvar%2Frun%2Fpostgresql`. An independent Rails runner makes a real connection and checks `current_database()`, PostgreSQL 16 and Unix-socket transport **before** a write.
4. Runs **only** `bin/rails db:migrate:up VERSION=20261117030000` on scratch, never `db:prepare`, `db:schema:load`, `db:reset` or all migrations. Verifies both new tables and version record afterwards. Does not change source preview DB.
5. Rails may regenerate the checked-out `db/schema.rb` as a **local working-tree file** based on the scratch DB. Inspect `git status -sb` and `git diff -- db/schema.rb`; do not reset it or commit the drift before review. The tracked original schema omits real `active_storage_*` tables present on local preview.

## QA and release gate
- CI static/dry-run tests confirm syntax, exact scratch name, required opt-in, explicit connection identity, single-target migration and hard refusal for production or generic DATABASE_URL.
- Exact-HEAD Rails model/controller, Chrome and Security audits required before user runs operator script.
- Actual scratch migration and resulting diff are **pending user terminal output**; do not infer PASS from CI. At this stage there is no owner chat UI, paid AI conversation, client access or automatic media ingestion.
- No main merge, Railway release or migrations against `rails_calendar_mvp_preview_20261112` without explicit owner approval, schema reconciliation and rollback plan.

## Follow-on
C2.1b White Atlas owner-only threads, new-message/archive UX and privacy/retention notice. C2.1c per-turn explicit paid consent/idempotency, controlled provider results and uncertain billing guard. Then content editing and wider client-facing releases per project master plan.
