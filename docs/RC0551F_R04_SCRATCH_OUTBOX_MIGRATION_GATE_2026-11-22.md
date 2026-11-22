# R0.4c / C2.3b1 — isolated PG16 scratch migration gate (2026-11-22)

**State 2026-11-22:** SCRATCH RESTORE + independent PG16 parity + detached worktree + Rails read-only target verified. The explicitly authorized ONE scratch migration `20261121003000` has now EXECUTED with primary local checks PASS; independently validated catalog/constraint audit PENDING. Preserve existing private backup, the restored scratch and original review DB. This is a runbook, not executable permission.

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

## R0.4c1 local code preflight — owner terminal PASS, 22 November 2026

Printed: `LOCAL_HEAD=c25be48`, `REMOTE_MIGRATION_BLOB=VERIFIED`, `HEAD_MIGRATION=ABSENT`, `WORKTREE_MIGRATION=ABSENT`, `SCHEMA_STATUS: M db/schema.rb`, empty `SCHEMA_DIFF_UNSTAGED` and `SCHEMA_DIFF_STAGED`, `READ_ONLY_CODE_GATE=PASS`. Exact migration content is available as Git blob `b1175a8ab37c5726fcaaae269adc7b1ea16892c7` under commit `36859c3` but is not in the original local checkout. Mode-only change to `db/schema.rb` is only a HYPOTHESIS; inspect `git diff --raw/--summary` without changes. No local files or DB written during this preflight.

GitHub comparison of code SHA `36859c3` to docs SHA `5f594b6` showed only documentation changes. Pin a dedicated detached Git worktree to **exact commit `36859c3086f6ece81630703145a7e82e8cd56159`**, not a moving branch. A worktree under `~/rails_calendar_r04_scratch_worktree_20261122` is deliberately separate from the owner's dirty original checkout and is not an SQL action.

**NEXT:** create that isolated worktree only if its path does not exist and all preflight guards pass; verify clean status, pinned migration hash and that the original checkout/scheme stays unchanged. Then perform a distinct read-only Rails scratch-connection gate. Migration requires another affirmative authorization; no `bin/rails db:migrate:up` yet, no `db:prepare` and no source DB writes.

## R0.4c2 separate detached worktree — owner terminal PASS, 22 November 2026

`ISOLATED_WORKTREE=PASS`, `MIGRATION_FILE=VERIFIED`, `ORIGINAL_CHECKOUT=PRESERVED`, `DATABASE_WRITES=NONE`. Created `~/rails_calendar_r04_scratch_worktree_20261122`, detached at exact `36859c3086f6ece81630703145a7e82e8cd56159`, clean; required migration blob matches pinned `b1175a8ab37c5726fcaaae269adc7b1ea16892c7`. Original `~/rails_calendar_ai_c21c` and `db/schema.rb M` preserved. `git diff --summary/--raw` blank; treat M as unexplained index state, do not reset or normalize.

**NEXT:** no checkout/restore repeat. With explicit scratch-only `RC_LOCAL_DEV_DATABASE_URL` built for local Unix socket, `DATABASE_URL` absent and `PGOPTIONS=-c default_transaction_read_only=on`, run Rails runner in the new worktree to confirm effective local PG16 scratch identity and migration pre-state. Check Ruby 3.4.13, runner code SHA and no Grok. If runner fails due gem/runtime/boot, capture sanitized error and STOP; do not install gems or mutate original checkout reflexively. No permission for actual migration.

## R0.4c3 Rails effective read-only scratch gate — owner terminal PASS, 22 November 2026

Owner ran `bin/rails runner` in detached `~/rails_calendar_r04_scratch_worktree_20261122` at `36859c3` with Ruby 3.4.13, development, Grok off, `DATABASE_URL` absent, `PGOPTIONS='-c default_transaction_read_only=on'` and scratch-only `RC_LOCAL_DEV_DATABASE_URL`. Rails ActiveRecord returned `RAILS_EFFECTIVE_DB=rails_calendar_r04_restore_20261121t231331z_27407`, `PG16_LOCAL_SOCKET=PASS`, `PG_TRANSACTION_READ_ONLY=PASS`, `OUTBOX_TABLE=ABSENT`, `MIGRATION_20261121003000=PENDING`, `RAILS_SCRATCH_CONNECTION_GATE=PASS`. This is a read-only PASS, not permission or evidence of DB migration.

**Explicit owner signoff is now the next gate.** Only authorize one isolated migration `20261121003000` on that scratch DB. Before execution recheck exact code/blob, scratch/source identity, version/table absence, source sessions and safety. Confirm the Rails process is constrained to scratch, not production/source. Migration invocation uses writable database session by design; validations default read-only. `db:migrate:up VERSION=20261121003000` may update the isolated worktree's `db/schema.rb`; NEVER touch original checkout's modified schema. On STOP or partial failure inspect and preserve the scratch; never auto-rerun or cleanup.

## R0.4c4 explicit write authorization — 22 November 2026

Owner approved one migration `20261121003000` exclusively to `rails_calendar_r04_restore_20261121t231331z_27407`, after fresh preflight, with original review DB, private archives, original `db/schema.rb` and Railway untouched. Authorization recorded; it is NOT a claim of execution.

Operator contract: recheck original checkout/schema, pinned migration hash and detached clean worktree, correct PG16 Unix socket source+scratch identities and no active writers, exactly one existing scratch, no outbox table/version and workspaces present; read-only Rails runner prove exact effective scratch target. Interactive typed local confirmation before the **single permitted writer**: `bin/rails db:migrate:up VERSION=20261121003000` with `RC_LOCAL_DEV_DATABASE_URL` scratch-only and `DATABASE_URL` unset. PGOPTIONS read-only for all guards and after-checks; unset ONLY for the approved DB schema writer. A schema dump (if Rails performs one) can modify `db/schema.rb` INSIDE the detached worktree only, never the original. Preserve private backup and scratch, no blind retry/rollback on failure. After owner terminal result, independent read-only index/FK/check constraints/table/row parity verification is mandatory before marking completed.

## R0.4c4 first attempt stopped at interactive owner gate — 22 November 2026

Owner verified `RAILS_EFFECTIVE_SCRATCH_PREWRITE=PASS`, but answered `MIGRATE-ONE-SCRATCH` instead of the expected `MIGRATE-ONE-SCRATCH-20261121003000`. The command returned `STOP: Confirmation refused` **before** `PREWRITE_GATES=PASS`, `MIGRATION_STARTED_SCRATCH_ONLY` and `bin/rails db:migrate:up`; thus this execution did not attempt DB writes. Do not classify as a migration failure or a successful DB change. No new independent psql after-check has been submitted yet.

Prior explicit owner permission is scoped to one scratch-only version `20261121003000`; repeat only after fresh read-only PG16 source/scratch identity/session/schema check, exact Git SHA and blob verification, and Rails read-only scratch target inspection; shorter interactive token `MIGRATE` replaces the previous long input to avoid accidental truncation. On any failure AFTER writer begins, stop and preserve both DBs and archives for investigation. Migration still NOT EXECUTED at this checkpoint.

## R0.4c4 scratch migration executed — owner terminal PASS, 22 November 2026

With explicit prior owner authorization, the guarded Rails command printed `RAILS_EFFECTIVE_SCRATCH_PREWRITE=PASS`, `PREWRITE_READ_ONLY=PASS`, accepted owner token `MIGRATE`, `PREWRITE_GATES=PASS`, `MIGRATION_STARTED_SCRATCH_ONLY`. Rails output shows only `20261121003000 CreateDomainOutboxEvents` and successful CREATE TABLE, unique revision index, delivery queue index and three CHECK statements; final markers: `MIGRATION_20261121003000_SCRATCH=PASS`, `SOURCE_OUTBOX=ABSENT`, `ORIGINAL_SCHEMA_CONTENT=PRESERVED`. Migration was executed on `rails_calendar_r04_restore_20261121t231331z_27407` from detached code `36859c3`; private archive, original review DB and original checkout remain outside the migration target. This is owner-terminal primary post-check evidence, NOT independent catalog verification.

**NEXT ONLY:** independent pinned PG16 local `psql` read-only audit for source absence of table/version, scratch presence exactly once, `schema_migrations` baseline parity after subtracting target, table counts source+1, six core row totals, zero outbox rows, correct NOT NULL columns, unique source-revision index, queue index, validated workspace FK and 3 named validated CHECK constraints. Do not rerun migration, restore, reset, rollback or cleanup, even if isolated `db/schema.rb` shows local modifications. On unexpected state keep scratch and investigate.
