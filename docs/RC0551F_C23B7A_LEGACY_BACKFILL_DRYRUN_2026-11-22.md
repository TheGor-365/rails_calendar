# C2.3b7a — Bounded legacy source reconciliation, read-only first slice

**Date:** 2026-11-22. **PR:** [#81](https://github.com/TheGor-365/rails_calendar/pull/81). **Scope:** code + synthetic test only; no local data scan, no production, no actual backfill.

## Why this is distinct from C2.3b6a

`DomainOutbox::Health.preview` reads already queued *due* `DomainOutboxEvent` records. Backfill inspection needs to detect historical canonical sources that have **no outbox envelope**. Reusing the due queue as a source audit would overlook precisely those omissions.

## Implemented in first source-only slice

- Code [`4fd8822`](https://github.com/TheGor-365/rails_calendar/commit/4fd8822f2d2cacd40643a621a51f7fd76ab8b004): `app/services/domain_outbox/backfill_dry_run.rb` and `test/services/domain_outbox/backfill_dry_run_test.rb`.
- **Single reviewed canonical mapping only:** workspace-owned `ProjectIntake`, source version `1`, outbox kind `intake_created` and activity key `ProjectIntake:<source_id>:intake_created`. Do not assume every legacy source uses this mapping: immutable scope, requirement revisions, invitation transitions, service publications and settled AI replies require separate version/timestamp/policy checks.
- `OperatorAccess.workspace_for!` enforces persisted owner-owned workspace; caller supplies NO arbitrary workspace ID or model name. Queries select only source IDs internally, only within this workspace, then exact matching outbox envelopes and ActivityEvent keys. No source text, answers, titles, files, prompts, token digests or AI results are read into preview output.
- **Bounds:** limit is a strict integer 1..25 per page; at most 250 scanned source IDs per cursor chain; `MAX(id)` freezes an upper source bound at initial page; keyset cursor advances `id > last_seen` and uses 15-minute AES-256-GCM encrypted, authenticated, owner/workspace/source-scoped token. Query may omit sources deleted or changed mid-scan: snapshot is **not** transactionally consistent across pages.
- Aggregate-only classifications per page: `already_indexed` (outbox + activity), `projection_only` (activity without outbox), `envelope_only` (outbox without activity), `missing_both`; fields: `source_type`, `inspected`, aggregate counts, `has_more`, `scan_budget_exhausted`, encrypted `next_cursor`. If budget is exhausted with more rows, `next_cursor=nil` intentionally blocks further automatic scanning; do not label the entire workspace reconciled.
- All paths are SELECT-only in application service; NO `insert_all`, `update_all`, `delete_all`, `Replayer`, Activity::Recorder, AI/provider, scheduler, POST route, GET endpoint or work against user-local databases. **Synthetic test setup** deliberately deletes artificial rows only in ephemeral CI test databases to simulate missing envelopes/projections; no owner-data repair.

## Acceptance scope and missing gates

- Tests: four independent envelope/projection combinations, idempotent aggregates and no DB/AI count deltas, strict role and page limits, malformed/foreign cursor denial, encrypted keyset paging and 250-row chain-budget denial.
- Functional code SHA `4fd8822`; exact [Rails CI #45028711017](https://github.com/TheGor-365/rails_calendar/actions/runs/45028711017) and [Security #45028711042](https://github.com/TheGor-365/rails_calendar/actions/runs/45028711042). Their complete results must be checked before `CI_VERIFIED`. Latest preceding HEAD `e647739` Rails #45028245547 and Security #45028245575 both SUCCESS.
- **Not delivered yet:** remaining five source families/version rules, globally bounded scan orchestration, explicit manual pacing/resume controls, snapshot stability contract, exact source-event eligibility validation and reconciliation report with signed off owner scope. No operator-triggered backfill writer, no rollback implementation, no automatic notification rebuild, no production scanning.
- **Next:** check exact SHA CI and fix failures; then extend source types one by one with independent synthetic eligibility/version tests, read-only before/after counts and human-signed per-workspace approval gate. Actual backfill remains a separate explicitly authorized DB write and deployment operation. Do not use already-verified scratch migration approval as authority to scan or mutate live source.

## Protected local state

`R0.4c4` and `R0.4c5` are independently `DB_VERIFIED_SCRATCH` in local PostgreSQL 16 `rails_calendar_r04_restore_20261121t231331z_27407`; original source review DB `rails_calendar_rc0551f_c21b_review_20261117` is unmigrated, private archive and all three distinct dirty local `db/schema.rb` files remain protected. This code commit did not access them. Railway, main and paid providers untouched.
