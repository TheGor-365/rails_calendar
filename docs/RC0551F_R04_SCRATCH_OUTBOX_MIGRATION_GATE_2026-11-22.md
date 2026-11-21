# R0.4c / C2.3b1 — isolated PG16 scratch migration gate (2026-11-22)

**State:** READ-ONLY PREPARATION ONLY. Migration NOT AUTHORIZED and NOT APPLIED. Preserve existing private backup, the restored scratch and original review DB. This is a runbook, not executable permission.

## 1. Grounded evidence

- Owner restored one NEW scratch via pinned script and personally confirmed `PASS R0.4b2`.
- Owner independently ran read-only pinned PG16 queries; outputs: `SCRATCH_DB=rails_calendar_r04_restore_20261121t231331z_27407`, `SOURCE_AND_SCRATCH_SCHEMA=PASS`, `CORE_ROW_COUNTS=PASS`, `SCHEMA_MIGRATIONS=PASS`, `POST_RESTORE_INDEPENDENT_READ_ONLY=PASS`, `MIGRATION_20261121003000=NOT_APPLIED`.
- Exact source review DB: `rails_calendar_rc0551f_c21b_review_20261117`, user `gor`, PG16.11 Unix socket. Six core table row counts and full migration version sets match. The source and scratch both lack `domain_outbox_events` before migration.
- User-local branch `local/rc0551f-c21c` historically at HEAD `c25be48`, modified `db/schema.rb`. The exact migration is **absent** in GitHub commit `c25be48`; it exists in remote feature SHA `36859c3` and later.
- Remote migration path `db/migrate/20261121003000_create_domain_outbox_events.rb`; pinned Git blob **`b1175a8ab37c5726fcaaae269adc7b1ea16892c7`**. Rails `ActiveRecord::Migration[8.1]`, creates private `domain_outbox_events` with workspace FK, unique `(workspace_id,source_type,source_id,source_version,kind)` index, delivery queue index and named CHECK constraints for source/version positivity, nonnegative attempts and allowed states.
- Previously verified recovery code SHA `36859c3`: Rails CI #44958765911 and Security #44958765901 SUCCESS. Last pre-preparation checkpoint `0b79d9d`: Rails CI #44961064956 and Security #44961065079 SUCCESS. New HEAD must be re-verified.

## 2. First operator action — independent READ-ONLY local code and environment audit

1. Print local `git rev-parse --short HEAD`, `git status --short`, staged/unstaged `git diff --numstat -- db/schema.rb`, installed Ruby/Bundler versions (without secrets), and whether the exact migration file exists in local working tree. Do NOT pull, stash, reset, checkout, overwrite or stage `db/schema.rb`.
2. Check presence/hash of the **remote Git object** for the migration using `git cat-file` and `git rev-parse SHA:path`; this may already exist locally from a previous `git fetch`. Do not materialize or execute the migration at this stage.
3. Reconfirm exactly one PG16 local scratch, source and scratch `domain_outbox_events` absence and `schema_migrations` absence of version `20261121003000`, plus no unrelated sessions; all SQL in `default_transaction_read_only=on`.
4. If drift, unexpected schema state, different scratch name or wrong source identity appears, STOP and investigate without modifying either database.

## 3. Proposed later writer design — requires a NEW explicit approval

- **Do not execute from old `c25be48` checkout** because the target migration is absent there. Prefer a separate, pinned exact-code isolated worktree for the scratch rehearsal, never replacing the user's modified checkout. Creating a worktree itself is an additional local filesystem write to be reviewed before performing.
- Confirm the isolated checkout contains the exact migration Git blob, correct Rails/Bundler dependencies, and `config/database.yml` takes `RC_LOCAL_DEV_DATABASE_URL` exclusively in `development`. Set `DATABASE_URL` absent, `RAILS_ENV=development`, `RC_GROK_ENABLED=false`, and use pinned PG16 local socket/role.
- Before the first DB write, use an explicitly read-only Rails runner to prove its **effective** connection targets `rails_calendar_r04_restore_20261121t231331z_27407` and not `rails_calendar_rc0551f_c21b_review_20261117` or Railway. Source and scratch cross-check may be repeated immediately before execution.
- After separate owner permission, apply **exactly** `bin/rails db:migrate:up VERSION=20261121003000` ONLY while Rails is connected to scratch; never plain `db:migrate`, `db:prepare`, `db:reset`, `db:schema:load`, the historical `rc0551f_c21a_migrate_scratch_only.sh`, nor any release command. Guard schema dumps/changes to remain in isolated worktree, never local `db/schema.rb`.
- On success perform independent pinned PG16 read-only verification: source has no outbox table and no new migration version; scratch has exactly one new migration version, correct columns, NOT NULL, workspace FK, unique source revision index, retry queue index, three CHECK constraints, and zero outbox rows initially. Confirm six core source vs scratch row counts unchanged. Preserve archive/scratch and do not auto-repeat on partial failure.
- Separate authorization and evidence required for migration of the **original** review DB, any data backfill, production PG18 release and cleanup. CI green is not owner-local acceptance, and PG16 scratch restore does not prove Railway storage recovery.

## 4. Next feature slices after scratch migration rehearsal

`C2.3b6b2/C2.3b6c2` controlled POST replay, actor audit and concurrency/rate safety → `C2.3b7` bounded dry-run backfill and reconciliation → `C2.3c` deterministic projection registry → `C2.4` validated human-approved AI Action Engine → `E1/E2.1–E2.5` real role-based client intake and exact-version approval → `M6/M7` project delivery/acceptance → `M8` gated PG18/Railway release and consented commercial pilot. Parallel owner UI QA of C2.2/C2.3 still needed.

Canonical [execution status](RAILS_CALENDAR_EXECUTION_STATUS.md) · [MVP roadmap](RAILS_CALENDAR_MVP_EXECUTION_ROADMAP.md) · [Draft PR #81](https://github.com/TheGor-365/rails_calendar/pull/81).
