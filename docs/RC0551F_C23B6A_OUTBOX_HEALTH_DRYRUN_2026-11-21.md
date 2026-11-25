# C2.3b6a — owner-only read-only outbox health and dry-run candidates

**Date:** 2026-11-21. **Scope:** Stacked Draft PR #81 (not merged or deployed). **Milestone:** C2.3b6 substep A, not full C2.3b6 completion.

## Live source of truth
Before next code change read [RAILS_CALENDAR_EXECUTION_STATUS.md](RAILS_CALENDAR_EXECUTION_STATUS.md), [MVP_EXECUTION_ROADMAP.md](RAILS_CALENDAR_MVP_EXECUTION_ROADMAP.md), current PR #81 HEAD and exact-SHA CI/Security. This document is a dated snapshot, not an instruction to redo already implemented steps.

## Implemented
- New internal `DomainOutbox::Health.snapshot(owner:, now:)` returns aggregate *private* queue metrics: total count, counts by pending/delivered/failed states, currently due candidates, failed-and-exhausted count (attempts >= max), cumulative attempt count, and age in seconds of oldest undelivered item.
- `DomainOutbox::Health.preview(owner:, limit: 1..100, now:)` selects a bounded stable ordered list of **candidates only** from the existing `DomainOutboxEvent.due` scope. It returns allowed kind/source type, revision number, attempt count and age. It does **not** fetch source bodies or expose source IDs, outbox IDs, tokens, private client answers, model prompts, file data or external URLs. It is *not* a guarantee the source exists/is deliverable.
- Both methods require a real persisted owner user with an existing workspace and then derive workspace scope from that owner; a caller cannot pass another tenant's workspace ID or impersonate a client. No HTTP route, service job, scheduler or replay trigger was added.
- All queries are SELECT-only. Neither method can call Grok/another AI provider, incur charges, deliver a notification or modify a canonical source.
- New focused synthetic tests assert state/due/backoff/exhaustion totals, oldest undelivered age, no leakage from another workspace, client/unassigned-owner rejection, bounded previews, no changes to `DomainOutboxEvent`, `ActivityEvent` or `AiSpendEntry`.

## Acceptance — separate dimensions
- **CODE:** committed in feature branch. Record exact code SHA after committing test.
- **CI:** [GitHub Actions PR #81](https://github.com/TheGor-365/rails_calendar/pull/81) Rails/controller and Chrome tests, PG18 fresh/upgrade, security audit; only mark PASSED after exact SHA results.
- **UI:** no new endpoint or screen. Future operator-only UI is NOT included and needs separate owner-access and browser verification.
- **DB:** this uses the preexisting C2.3b migration, which still does NOT exist in the user's separate local PG16 review DB. No local migration or backup+restore is performed by this GitHub commit.
- **PROD:** not deployed. No Railway changes, new AI requests or client notifications.

## Next substeps
1. **C2.3b6b** Explicitly authorized owner-only operator interface for inspecting health without private values. A replay action (if added) must use CSRF protection, explicit limit <=100, worker concurrency protection, no automatic paid provider call and visible actor audit.
2. **C2.3b6c** Locking/retry/metrics hardening and bounded replayer safety, failure-rate/dead-letter alerts with verified no-PII output; human review of repeated source failure reasons.
3. **C2.3b7** Bounded dry-run legacy backfill from actual canonical revisions, with page cursor, idempotency key, source-version checks and a before/after reconciliation report. No blind production scan or automated backfill.
4. **C2.3c1–c6** Deterministic view projections and per-tenant ACL for calendar/day/hour, library/exports, owner notifications, tasks and AI-reused artifacts.
5. C2.4 AI proposals → human-reviewed atomic apply → source/outbox updates, then E2.4 12-section R-ID requirements, E2.5 dual exact-version approval, M6–M8 execution and separately authorized release.

## Current local environment blocker / safe action
User installed and selected Ruby **3.4.13** with `ASDF_RUBY_VERSION`, but its gem installation is empty: `ruby bin/rails --version` fails with missing `rails 8.1.4.1` and many other lockfile gems before any DB access. Run `BUNDLE_FROZEN=true bundle install --jobs 4 --retry 2` while `ASDF_RUBY_VERSION=3.4.13`; then `bundle check && ruby bin/rails --version`. This installs gems for the new Ruby without changing Gemfile.lock or applying migrations. Report exact error if Bundler cannot compile a gem. Never delete or overwrite modified `db/schema.rb`.

User's prior read-only `psql` target `rails_calendar_rc0551f_c21b_review_20261117` PostgreSQL 16.11 Unix socket has no `domain_outbox_events` table. Actual Rails process connection, storage snapshots, private backup and scratch restore are still unverified. Old backup scripts target a different database, so **do not run them**. See [R0.4 safety gate](RC0551F_REVIEW_DB_BACKUP_MIGRATION_GATE.md). Existing :3002 server and original :3001 remain protected. No local DB migration/backup or Railway production action by the assistant.
