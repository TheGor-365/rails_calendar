# RC055.1f — E2.5 Library and navigation UI checkpoint (2026-11-21)

## Implemented
- Owner requests screen already shows incoming and outgoing requests with local view preference.
- Header and mobile navigation label is **Requests** rather than **Incoming requests**.
- Owner nav now highlights the active Library route and grouped Requests, invitation, and requirements routes with aria-current where applicable.
- Library has White Atlas responsive left rail, icon category chips, counts from existing owner-scoped records, date presets (7/30/all), explicit date range, quick links.
- Library free text, type, and date filters work on preloaded owner-scoped items instantly via Stimulus and no reload. URL query reflects filters. Server-side ACL unchanged. Currently indexes latest 100 persisted records per source.
- Category select, search, date controls and action buttons aligned to a common 43px height.
- Native details are enhanced with smooth variable-height animation, with reduced-motion support and native fallback, including nested content preview.
- Original artifact TXT export remains generated from persisted source data. No migrations, no model keys, no paid AI calls.
- UI regression assertions added to E2 controller test for filter targets and nav active state.

## Current limits / next engineering stage
1. GitHub Actions CI and Security Audit must be checked on current HEAD; local test run still required.
2. Library search is instantaneous but only across the **loaded** capped set of authorized records. For scale, implement server-side paginated search with asynchronous Turbo Frames, accurate total counts and stable filters.
3. Generalize active nav for all secondary sections, including client-side flow; additional routes need regression coverage.
4. Implement a durable, workspace-scoped **ActivityEvent** append-only audit/outbox architecture, with idempotent event keys, provenance, actor, entity type/id, timestamps, linked revisions, AI usage, status and appropriate access control. Design transaction boundary before implementation.
5. Surface events in owner timeline, calendar/day pages, notifications, library and client activity with authorization per viewer. Distinguish notifications (user-facing state) from immutable event log (audit).
6. Build rich structured artifacts, full immutable specification export, project task links, semantic search, source lineage and review workflow in incremental tested slices.
7. Never rewrite historical AI spends or approved scope versions; no automatic paid AI requests and no production release without backup/restore and isolation gates.

## Local verification
In the existing `~/rails_calendar_ai_c21c` terminal, check `git status --short`, `git pull --ff-only origin feat/rc0551f-c21c-live-owner-ai-chat-2026-11-18`, then `yarn build && yarn build:css`. Test only with verified isolated `rails_calendar_rc0551f_e2_test_20261119` DB and `RC_GROK_ENABLED=false`. Browser check on port 3002, never affect port 3001.
