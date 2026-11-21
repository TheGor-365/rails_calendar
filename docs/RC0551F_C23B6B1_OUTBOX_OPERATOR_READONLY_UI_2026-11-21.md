# C2.3b6b1 — private read-only operator diagnostics UI

**Date:** 2026-11-21. **Repository:** TheGor-365/rails_calendar. **PR:** #81, stacked Draft. **Functional code checkpoint:** `e86af5e908ec53f2043268152ca8c34b887930e6`. **Acceptance:** code committed, exact-SHA Rails CI/Security pending at authoring. This document is not real-time truth: read the latest PR head and `docs/RAILS_CALENDAR_EXECUTION_STATUS.md` before any new action.

## Implemented in this narrow slice
- Owner-only route `GET /workspace/outbox/health`, `OwnerOutboxHealthController#index`; denies anonymous users, clients and owners without workspace using 404. Cache-Control private no-store and nosniff.
- Reuses existing C2.3b6a `DomainOutbox::Health.snapshot(owner:)` and `preview(owner:, limit:)`. No alternative queue, no alternate DB model or new migration.
- Responsive view with aggregated pending/delivered/failed/due/exhausted/cumulative attempts and oldest undelivered age. Bounded candidates display only source *type*, event *kind*, version, attempt count and age. No source IDs/outbox IDs/answer bodies/prompts/files/token digests.
- Selectable GET limit: strict allowlist 10/25/50/100 (fallback 25), no free-text query or unbounded pagination.
- Link to diagnostics from private owner activity journal; back navigation to journal and owner library. Labels provided for RU, EN, HY and ES.
- Four synthetic integration tests cover private GET and no event/ledger changes, cross-workspace isolation, client/guest/owner-without-workspace denial, malformed limits, absence of replay POST controls, navigation link and no identifier disclosure.

## Explicit boundaries
- **This is only C2.3b6b1**, a READ-ONLY operator interface. There is no POST/DELETE replay action, background job, retry of source, AI provider call, client-facing route, mass backfill or deploy. Do not mark full C2.3b6b/c as DONE.
- Security authorization derives the workspace only from authenticated current_user, never a query-supplied workspace ID.
- Last green predecessor: `981ebf1c67ca5c7b6f58e6e92d8ce8eab37c52eb`, Rails CI [44914065690](https://github.com/TheGor-365/rails_calendar/actions/runs/44914065690) SUCCESS, Security [44914065635](https://github.com/TheGor-365/rails_calendar/actions/runs/44914065635) SUCCESS. Current exact functional SHA needs its own green Rails CI, Chrome, PG18 fresh+upgrade and Security before CI_VERIFIED.
- The user's local application is **not** running these changes yet; source is in the remote Draft branch only, no local DB migration or Railway update.
- Manual UI review at owner 320/390/1440 widths, client/guest, tab navigation and no GET writes remains pending.

## Owner local env / R0.4 gate
- Confirmed Ruby 3.4.13, Rails 8.1.4.1, Bundler 2.6.9 and successful `BUNDLE_FROZEN=true bundle install` (92 gems, `bundle check` satisfied); `db/schema.rb` still locally modified.
- Previously read-only checked PG16.11 Unix socket DB `rails_calendar_rc0551f_c21b_review_20261117` with `domain_outbox_events` **ABSENT**. This was a separate `psql` check, not proof of effective Rails DB used by the :3002 process.
- Now that gems work, next safe verification is a guarded `RAILS_ENV=development PGOPTIONS='-c default_transaction_read_only=on' ruby bin/rails runner 'SELECT current_database(), current_user, current_setting(...)'`; never echo `DATABASE_URL`, never call migrate/prepare/reset/restore/clean/stash.
- R0.4 requires exactly targeted private database/Active Storage snapshot + verified **scratch restore** before any user-initiated local outbox migration; the old backup scripts refer to a DIFFERENT database.

## Remaining sequence after green CI
1. C2.3b6b2 / C2.3b6c: explicit supervised replay command/owner action only after R0.4 and safety review, CSRF, bounded limit, idempotence, concurrency locks, actor audit, no provider billing. Read-only operator diagnostics must remain useful without these.
2. C2.3b7: dry-run historical source backfill plan, paged and scoped with immutable version checks, no blind writes.
3. C2.3c1–c6: deterministic projection registry, read-only authorized calendar/day/hour/library/notifications, lag/lineage/deep links, consistency/rebuild metrics.
4. C2.4: typed AI ActionProposal, consent, validated diff, explicit owner apply, transactional outbox, deterministic no-cost propagation.
5. E2.4/E2.5 12-section R-ID source-traceable client requirements and bilateral immutable exact-version approval; M6/M7 tasks/assets/QA/delivery; M8 staged release gated by backup, ACL, real QA, user authorization.

**Status protocol:** separate CODE_SHA, CI_RUNS, UI_EVIDENCE, DB_EVIDENCE, PROD_SHA, BLOCKERS. Any new HEAD supersedes this snapshot and must be verified again.
