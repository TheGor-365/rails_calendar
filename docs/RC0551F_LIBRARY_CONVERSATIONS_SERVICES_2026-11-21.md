# Rails Calendar — E2 library expansion: conversations and service revisions (2026-11-21)

## Proven baseline
The owner confirmed successful fast-forward to `0695490`, esbuild and Sass builds, and migration of `activity_event_reads` on the two isolated UNIX-socket databases. Test output: **49 tests / 940 assertions / 0 failures / 0 errors / 0 skips**.

## What changed
The existing owner-only `/workspace/library` now projects two additional persisted source collections:
- **AI conversations:** owner workspace conversations, state and title, most recent *settled* assistant answer as compact preview. Direct link to the original conversation. TXT export contains ordered existing messages, role/state/sequence/body, operation, cost-ledger reference and *metadata only* for file attachments (no direct public blob links).
- **Service revisions:** versions belonging to `ServiceOffering` rows in the owner's workspace, immutable canonical business description and source digest. Direct link to service editor; TXT export with complete canonical fields.
- Taxonomy, category icons and client-side filtering updated for RU, EN, HY, ES.
- Data never duplicated into new documents/tables; all exports read authoritative records at request time.
- Both types scoped to the current owner's workspace. Cross-owner access returns 404; no new paid AI request or migration.

## Verification
1. In the existing `~/rails_calendar_ai_c21c`, verify `git status --short` (local `db/schema.rb` is modified and must not be discarded), then fast-forward pull and run `yarn build && yarn build:css`.
2. Under the already configured **test** UNIX-socket URL only: verify `DATABASE_URL` absent, `current_database() == rails_calendar_rc0551f_e2_test_20261119`, `inet_server_addr() == socket`. Run `RAILS_ENV=test RC_GROK_ENABLED=false RC_LOCAL_CLIENT_REQUESTS_ENABLED=true PARALLEL_WORKERS=1 bundle exec rails test test/controllers/e2_client_invitation_test.rb test/controllers/consultations_controller_test.rb test/controllers/pages_controller_test.rb`.
3. In owner browser session on port 3002, open `/workspace/library`: use new **AI conversations** and **Service versions** category filters, expand records, preview, open source and export TXT. Confirm no content from another owner is visible.
4. GitHub CI/Security for this SHA not yet confirmed; local runtime acceptance not performed by assistant.

## Next slices
- Attachments as first-class library references with ACL, content type, size, scan policy and download through original owner-only routes.
- Scope snapshots and AI conversation turns with clear provenance; full-text search over source-backed indexes, pagination and proper date/count accuracy.
- Link the artifacts registry with activity events, project dashboards, calendar and notification cards; no commercial release before prod DB backup/restore and other deployment gates.

## Safety
Do not touch the original Rails directory, port 3001, production Railway, payment methods, secrets, or other PostgreSQL databases. No external model call unless separately authorized.
