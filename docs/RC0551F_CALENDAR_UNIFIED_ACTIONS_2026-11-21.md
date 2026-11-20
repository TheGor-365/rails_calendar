# RC0551f / Calendar unified actions checkpoint — 2026-11-21

## Motivation and architecture
The existing month and 24-hour day grid correctly store and position `Consultation` records, but owner invitations, AI spend ledger entries, project intakes and immutable requirements versions existed in other tables and previously did not appear as dated owner activity. Do **not** create dummy Consultation events for these records.

## Delivered in the current branch
- Fixed duplicate `aria:` keyword warning on consultation navigation.
- Added authenticated calendar action menu and reusable native popover for each date/hour cell. Actions point to existing routes: inline consultation composer, invitation, new intake, library, owner AI.
- Inline consultation form uses the existing guarded `ConsultationsController#create` via JSON, server validations and CSRF. Turbo refreshes the **same** calendar URL on success; it does not navigate to the standalone new-consultation page. Nothing is submitted to Grok.
- Month and day render date-aware subtle past/future contrast. Day has a current-time line with pointer-events disabled to avoid blocking event interaction.
- New `Calendar::OwnerActivity` is a **read-only, workspace-scoped projection** from persisted invitation records, ProjectIntakes, AiSpendEntries and IntakeRequirementSets. AI spend entries include failed and uncertain attempts; show their actual recorded status. It is not an append-only event table.
- Owner activity shown in relevant month cells, and as White Atlas cards under the month grid, day schedule and hourly view, with source links.
- RU/EN/HY/ES UI strings, scoped styles, controller tests for JSON creation / validation and owner-only calendar visibility.

## Safety and scope limitations
- No migration, DB cleanup, production deployment, authorization weakening, paid AI API call, or manipulation of port 3001.
- Individual consultation records remain under the **legacy global calendar schema**; do not silently claim they are workspace-scoped.
- Month calendar appointments remain sourced from `Consultation`; owner activity projection is read-only and separate.
- Current inline save re-renders the **same page with Turbo** after successful JSON POST; finer-grained Turbo Stream DOM updates are a future improvement.
- Creation of invitation/intake/AI artifacts currently follows existing route screens rather than a fully inline editor; those routes are real and guarded. Broader 'create anything' multi-artifact wizard requires further design.
- Not all AI chat messages or legacy sources have one durable canonical event; architect a workspace-scoped `ActivityEvent` + notifications outbox and idempotent service events next.

## Validation gate
- Review GitHub Actions on current HEAD; run `yarn build && yarn build:css` and isolated test DB tests `test/controllers/consultations_controller_test.rb`, `test/controllers/pages_controller_test.rb`, `test/controllers/e2_client_invitation_test.rb`.
- Ensure terminal is `~/rails_calendar_ai_c21c`, `RAILS_ENV=test` for test, `RC_GROK_ENABLED=false`, no generic `DATABASE_URL`, and psql says `rails_calendar_rc0551f_e2_test_20261119` on UNIX socket. Do NOT run migrations without an explicit DB check.
- Browser validate month/day/selected hour, cell popovers, inline create, event display, private cross-owner isolation, mobile responsiveness, and visual alignment with White Atlas.
