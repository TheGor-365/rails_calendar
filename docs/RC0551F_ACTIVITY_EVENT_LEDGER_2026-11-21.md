# Rails Calendar — activity event ledger checkpoint (2026-11-21)

## Scope and reason
The previous calendar layer projected several source tables independently. This made historical content visible but did not create a durable event for every new action, status change or paid AI attempt. This slice establishes an **append-only owner workspace activity index**, without moving source records or charging an AI model.

## Implementation
- `db/migrate/20261121120000_create_activity_events.rb`: `workspace_id`, unique `event_key` per workspace, enum-like `kind`, source type/id, title, event time, small allowlisted metadata, one created timestamp. PostgreSQL source and time indexes.
- `ActivityEvent`: application-level immutable event. Stored metadata is deliberately bounded; no bearer link, token digest, client answer, raw prompt, attachment or secret.
- `Activity::Recorder.record!`: single insert using PostgreSQL conflict avoidance on unique key. A repeated lifecycle callback is idempotent.
- Model hooks at persistence boundaries for issued/claimed/submitted/revoked invitations; created requests; immutable requirements versions; AI spend attempts and settled/uncertain/cancelled outcomes; newly created owner AI conversations. Client/owner authorization and existing schemas of these source models remain unchanged.
- `Activity::Presenter`: allowlisted source navigation; no generated private URLs.
- Owner-only `/workspace/activity` with bounded timeline, live Turbo-frame search, category/date filters, White Atlas cards and one-click TXT metadata export at `/workspace/activity/:id.txt`. Scope is always current owner's workspace.
- Month/day/hour calendar projections read events first and preserve older historical content. Links to journal from calendar, library and workspace. UI localized RU/EN/HY/ES.
- Tests cover idempotence, owner isolation, event export, AI reservation-to-settlement and link visibility.

## Safety and release gates
- Local and test DB migration required before loading pages/models using event callbacks. **Do not run a generic migrate against any other database.**
- Existing user-local `db/schema.rb` was modified by prior isolated migrations. Remote schema file was not overwritten because older snapshots conflict with the user's latest local schema.
- This is application-level immutability, not a database-level prohibition on privileged SQL DELETE/UPDATE. Stronger DB audit/retention policy is a separate design decision.
- Events are metadata pointers, not full documents or files. Canonical source records remain in original tables. The TXT export is provenance, not a copy of the full artifact.
- Existing history is still visible through the read-only fallback; no backfill that changes or duplicates existing content was run.
- No notification delivery, unread cursor/acknowledgement or external email push yet. This follows event ledger validation.
- No data reset, production deployment, change to protected port 3001 or paid Grok calls.

## Validation
In existing Linux terminal in `~/rails_calendar_ai_c21c`, inspect `git status --short`, pull with `--ff-only`, compile JS/CSS.
For each review DB, validate exact database name and local UNIX socket before `bundle exec rails db:migrate`. Test DB name `rails_calendar_rc0551f_e2_test_20261119`; dev name `rails_calendar_rc0551f_c21b_review_20261117`.
Run tests with `RC_GROK_ENABLED=false RC_LOCAL_CLIENT_REQUESTS_ENABLED=true PARALLEL_WORKERS=1` under explicit `RAILS_ENV=test`. Verify journal, calendar, invite lifecycle and AI ledger from browser; check GitHub CI/Security status for exact commit.

## Next
1. Verified migration and local browser acceptance.
2. Durable notification inbox with read cursors and status changes, plus links to canonical events; external delivery only with explicit configured policy.
3. Artifact registry and producer adapters for AI chat outputs, service revisions and all file/doc variants; transactional outbox where appropriate; never create duplicate source content.
4. A unified command palette and AI creation presets, retaining all ACL and paid-provider budget guards.
