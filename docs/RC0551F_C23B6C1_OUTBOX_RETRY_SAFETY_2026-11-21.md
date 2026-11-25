# RC0551F C2.3b6c1 — bounded retry, stale-worker protection, terminal failure

**Date:** 2026-11-21. **Target:** stacked Draft PR #81, feature branch only. **Code SHA:** `39e809634719b60f993dffa8480e92b298700f9a` (verify actual current HEAD before any new work). This is a C2.3b6c **substep**, not authorization for an operator replay button or a release.

## Why this is needed
Existing `DomainOutbox::Replayer.run!` first locks an outbox row, runs one idempotent activity projection in that transaction, and acknowledges success. On a source error, it rolls back and then reacquires a lock to mark failure. Between rollback and reacquiring a lock, another worker may have handled the row. The previous code incremented the **then-current** attempts without matching the attempt that actually failed, potentially overcounting a stale result. The old failure handler also recorded a future retry timestamp even after `MAX_ATTEMPTS` was exhausted.

## Code contract
- Capture `attempts_before` **inside the first row lock** when the delivery is genuinely due. The saved activity projection and success acknowledgement still commit in the same transaction.
- On failure, the handler reacquires a row lock and updates failure metadata **only if** the row still has that attempt count and is `pending` or `failed`. A completed or independently advanced row is never marked failed again. No external AI provider, emails, client actions or arbitrary source class constantization.
- Failure metadata stores only `error.class.name` truncated to 80 characters, never exception messages, client answers or provider details.
- Preserve exponential retry delay `2**attempts` seconds (existing maximum 3600). Once `MAX_ATTEMPTS` (5) is reached, mark `state: failed`, keep `last_error_code`, set `next_attempt_at: nil` and leave the row outside `DomainOutboxEvent.due` forever unless a separately reviewed manual recovery action is designed.
- No new migration, controller, route, worker, task or paid AI call.

## Synthetic acceptance tests
`test/services/domain_outbox/replayer_safety_test.rb`:
1. One missing persisted source is attempted only when due. Subsequent delays are 2, 4, 8, 16 and terminal failure on attempt 5. No retry at intermediate timestamps or in the far future. Health snapshot records `exhausted: 1` and preview is empty.
2. Fixed `limit: 1` processes one due item at a time, skips delayed records, does not touch another workspace, and rejects 0 / 101. Exact source/ledger/activity counts unchanged.
3. Error class is allowlisted by source processing and contains no message; idempotent retries never call AI.

### Verification and constraints
- Earlier UI code fix `306fdc1c83969f2209f32d0b243bdfb30c016221` is CI and Security **SUCCESS**: [Rails CI #44922808417](https://github.com/TheGor-365/rails_calendar/actions/runs/44922808417), [Security #44922808402](https://github.com/TheGor-365/rails_calendar/actions/runs/44922808402).
- Current C2.3b6c1 functional [Rails CI #44923093762](https://github.com/TheGor-365/rails_calendar/actions/runs/44923093762) and [Security #44923093845](https://github.com/TheGor-365/rails_calendar/actions/runs/44923093845) require exact-SHA inspection before marking green; Security SUCCESS at this snapshot, CI still RUNNING.
- No stress/integration proof with parallel real workers is claimed; such a test and operator audit are still outstanding C2.3b6c2/R0.4 work.
- User confirmed via **Rails runner read-only SELECT** that the standalone local development connection is database `rails_calendar_rc0551f_c21b_review_20261117`, role `gor`, PostgreSQL 16.11 via Unix socket, outbox table **absent**. This does **not** establish the connection of the already-running :3002 process.
- User Ruby 3.4.13, Rails 8.1.4.1, 92 gems `bundle check` PASS. Locally modified `db/schema.rb` must remain untouched. No local migration or restore, no Railway/main change.

## Next checkpoints
1. Check exact-SHA CI/Security after C2.3b6c1; fix any Rails/Chrome/PG18 failure, update live `docs/RAILS_CALENDAR_EXECUTION_STATUS.md` after evidence.
2. R0.4: verify local Active Storage backend, backup exact observed review DB to user-private location, restore to a **new scratch DB**, verify checksum/row/media integrity before any review DB migration. Old scripts point to the wrong database; do not reuse blindly. Local operations require the user to execute and confirm.
3. C2.3b6c2: concurrency and operator audit design (owner authentication, explicit POST/CSRF/limit, no AI provider call); remain disabled until R0.4 and manual approval.
4. C2.3b7: read-only legacy backfill preview with stable pagination, versions, and no source text; then C2.3c calendar/library/notifications consistency, C2.4 typed AI proposal/diff/apply, E2.4/E2.5 R-ID/approval, M6–M8 MVP release.

**Checkpoint semantics:** CODE_COMMITTED is not UI_VERIFIED, DB_VERIFIED or PROD. A roadmap step present in this dated file may have been implemented in newer GitHub commits; always recheck current head.
