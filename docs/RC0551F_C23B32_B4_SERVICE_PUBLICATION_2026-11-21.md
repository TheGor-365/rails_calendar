# Rails Calendar — C2.3b3.2 and C2.3b4 implementation checkpoint

Date: 2026-11-21. Development branch: `feat/rc0551f-c21c-live-owner-ai-chat-2026-11-18`, stacked Draft PR #81. **This document is a snapshot; always re-read `docs/RAILS_CALENDAR_EXECUTION_STATUS.md`, live GitHub HEAD, and exact-SHA CI before new work.**

## C2.3b3.2 — invitation transition provenance
- Existing invitation source `ClientRequestInvitation` and `DomainOutboxEvent` are reused; no new model, migration, invitation or client message.
- Replay of `invitation_issued/claimed/submitted/revoked` now checks that the still-persisted source timestamp exactly matches the immutable event timestamp (second precision). An updated/tampered source fails closed using the existing bounded retry and error-code machinery; it is not silently rewritten as a different historical event.
- Synthetic model tests cover claimed and submitted transitions (DB claim triplet and source version indexes), duplicate/no-op updates and replay, rollback of revoked_at, drifted timestamp rejection, tenant isolation and unchanged AI ledger.
- This is *not* a new invitation policy: historical invitation edits or status interpretation must not be invented by a replay job.

## C2.3b4 — service publication is a real, immutable audit source
- `OwnerServices::Catalogue#publish!` and `#unpublish!` already enforce an owner's explicit confirmation. `ServiceOfferingPublication` records those real operations as immutable append-only audit rows. **Do not create a second publication registry, auto-approve a service, or confuse the mutable `ServiceOffering#published_version_id` pointer with history.**
- Added `ServiceOfferingPublication` as an allowlisted `DomainOutboxEvent` source. `publish` → `service_published`; `unpublish` → `service_unpublished`. Each unique audit row is source version 1. Enqueue is in the **same transaction** as creation of the publication audit. The existing immediate ActivityEvent projection is created after commit, using the same idempotent key as replay.
- A valid publish audit must reference an owner-approved immutable `ServiceOfferingVersion` belonging to the exact service. An unpublish audit has no version pointer. Cross-owner and cross-service sources are rejected.
- Replay checks the exact immutable audit row and owner workspace, validates the source event/revision, and restores only a missing `ActivityEvent`. It does not change published version pointers, send notices, call Grok or generate content.
- `Activity::Presenter` resolves the owner's service page with an allowlisted Rails route; calendar and activity journal show localized statuses and category for RU/EN/HY/ES. No public/client projection or automatic publication is enabled.
- Tests: owner approved publication, unpublication, no duplicate on replay, missing event restore, cross-workspace isolation, unapproved version blocked, DB rollback removes source/outbox/activity. No paid provider calls.

## Proof / acceptance gates
- **CODE_COMMITTED** in Draft PR #81. See actual latest HEAD; the code checkpoint before writing this document was `4f2faf5eb18ed5b408c26921db4c06422bfdcc2e`.
- **CI_VERIFIED only if exact code SHA passes:** Rails model/controller, Chrome system, PG18 fresh and actual deployed-baseline upgrade, Security Audit. Do not infer PASS from an earlier commit or docs-only HEAD.
- **LOCAL_BROWSER_VERIFIED — NOT DONE:** local checkout remains `c25be48`, original port 3001 protected, app port 3002 on older checkout, direct owner month/day/hour → service links untested locally.
- **DB_VERIFIED — NOT DONE:** user's specific read-only PG16.11 socket DB is `rails_calendar_rc0551f_c21b_review_20261117`, `domain_outbox_events` absent. Keep modified local `db/schema.rb`, do NOT use historical backup scripts for another database. See `docs/RC0551F_REVIEW_DB_BACKUP_MIGRATION_GATE.md`.
- **PROD — BLOCKED:** no merged PR, staged Railway migration, backup+restore or actual production publish.

## Remaining order to MVP
1. Exact-SHA CI fixes if needed, then update live `RAILS_CALENDAR_EXECUTION_STATUS.md` with codes and run IDs.
2. R0.4: identify Rails effective DB and real Active Storage backend, verify offline private backup and scratch restore for the specific local DB before any migration; only user runs local writes.
3. C2.3b5 private `ProjectIntake` and `IntakeScopeRevision` source adapters, ensuring owner/client drafts never leak; C2.3b6 queue metrics/replay health; C2.3b7 bounded dry-run backfill after explicit approval.
4. C2.3c deterministic source-backed projections; C2.4 controlled action proposal → human diff → transaction → one outbox → many views, no provider rebilling.
5. E2.4 12-part R-ID client requirements + provenance/versions/criteria; E2.5 bilateral approval on exact immutable version; M6–M7 tasks/assets/delivery/acceptance; M8 secure, separately-authorized Railway production MVP.

Do not treat code-complete as local DB, browser, or production acceptance.
