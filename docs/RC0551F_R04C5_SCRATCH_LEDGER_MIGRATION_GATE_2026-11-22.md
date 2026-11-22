# R0.4c5 — target-only replay audit ledger migration authorization / scratch guard

**22 Nov 2026 | STATUS: OWNER-AUTHORIZED / NOT EXECUTED OR VERIFIED.**

User approved **only** migration `20261122130000` on scratch PostgreSQL16 `rails_calendar_r04_restore_20261121t231331z_27407`, subject to repeated gate checks. Source review `rails_calendar_rc0551f_c21b_review_20261117`, backup root `~/.local/share/rails-calendar/review-backups-r04`, original checkout `~/rails_calendar_ai_c21c` with dirty schema, older detached worktree `~/rails_calendar_r04_scratch_worktree_20261122` with DIFFERENT dirty schema, Railway and main are not migration targets. No replay calls, no HTTP route, no paid AI.

### Exact code and writer

- Pinned code commit: `b5579f9c57642335100f0da68a811f2c996d3099` (feature branch Draft PR #81).
- Only migration path `db/migrate/20261122130000_create_owner_outbox_replay_runs.rb`; Git blob `5241c5ec7020140f51f5756c298a28e29a91069f`.
- Prepare a **THIRD** separate detached worktree `~/rails_calendar_r04_ledger_worktree_20261122`; do not pull/reset/stash either existing tree, never copy dirty schemas or touch private backup files. Worktree creation writes only new code files and Git worktree metadata.
- Verify PG16 local socket/db names, source outbox and new ledger both absent, scratch prior outbox migration `20261121003000` applied once, new ledger version/table absent, existing scratch outbox zero rows, private backup directory remains, original two schema contents unchanged.
- Rails actual effective connection must prove exact scratch database on Unix socket, `transaction_read_only=on` during preflight. After explicit operator confirmation, run only `RAILS_ENV=development bin/rails db:migrate:up VERSION=20261122130000` from new pinned isolated worktree and only with explicit scratch URL; omit `DATABASE_URL` and read-only PGOPTIONS for migration writer. PostgreSQL DDL normally transactional; on failure do not auto-retry, migrate source, rollback or reset.

### Required independent postwrite acceptance (PENDING)

- Scratch exactly one new schema_migrations version `20261122130000`, table `owner_outbox_replay_runs` present, zero rows, unchanged older outbox/rowcounts and exactly +1 public table.
- Indexes `idx_outbox_replay_workspace_request` unique and `idx_outbox_replay_one_running` unique with `WHERE state = 'running'`, 2 validated FKs (owner_user to users, workspace to workspaces), 5 valid named checks (`chk_outbox_replay_run_state`, `chk_outbox_replay_run_limit`, `chk_outbox_replay_run_counts`, `chk_outbox_replay_request_digest`, `chk_outbox_replay_finished_state`), core column NOT NULL and safe defaults.
- Source still has no outbox, no audit table and neither new version; original and first detached worktree schemas still have their original different hashes and worktree dirty state; archive preserved.
- Final status **ONLY after owner-supplied proof:** `R0.4c5 = DB_VERIFIED_SCRATCH`. Successful scratch migration does not enable POST or real replay.

## Owner operation executed and primary postcheck PASS — 22 November 2026

**Do not repeat the migration.** Owner terminal provided `PG16_SOURCE_AND_SCRATCH_PREWRITE=PASS`, `RAILS_EFFECTIVE_SCRATCH_READ_ONLY=PASS`, `PREWRITE_GATES=PASS`; typed exact `MIGRATE-LEDGER-SCRATCH-20261122130000`. Rails output `CreateOwnerOutboxReplayRuns: migrated (0.0585s)` shows one new ledger table, both unique indexes, five named CHECK constraints. Immediately afterward `MIGRATION_20261122130000_SCRATCH=PASS`, `SOURCE_REVIEW_DB=UNMODIFIED_MIGRATION_STATE`, `PROTECTED_SCHEMA_CONTENTS=PRESERVED`, `NEXT=INDEPENDENT_READ_ONLY_CATALOG_AUDIT`; third code worktree `~/rails_calendar_r04_ledger_worktree_20261122` has ` M db/schema.rb` (preserve). This is **owner-terminal primary success**, not independent SQL catalog acceptance.

**Next single authorized action = READ-ONLY independent PostgreSQL16 audit.** Verify source neither outbox+ledger nor versions, scratch both versions once, scratch +2 public tables vs source, legacy migration-version baseline parity after removing two target versions, five core source/scratch row totals, empty outbox/ledger, 9 mandatory NOT NULL ledger columns, running state and 0 attempt defaults, two valid unique indexes (running partial predicate), two validated FK to workspaces/users and five named validated CHECK constraints. Original and prior detached schema hash baselines preserved; audit runs with `PGOPTIONS='-c default_transaction_read_only=on'`. If any mismatch, STOP; no migration replay or cleanup. `R0.4c5=DB_VERIFIED_SCRATCH` only on owner independent PASS, never based on this primary postcheck alone.
