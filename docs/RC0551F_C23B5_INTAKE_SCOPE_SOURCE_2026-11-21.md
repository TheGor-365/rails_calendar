# Rails Calendar — C2.3b5: project intake + immutable client/owner scope outbox

Date: 2026-11-21. Scope: stacked Draft PR #81, code in the feature branch only. **This is a checkpoint, not a declaration of CI/UI/DB/PROD acceptance.** The next assistant must reread the latest GitHub PR HEAD, checks and `docs/RAILS_CALENDAR_EXECUTION_STATUS.md` before working.

## Exact sources; no duplicate models
- `ProjectIntake` (existing, may be unassigned legacy `workspace_id=NULL`): allowed outbox kind `intake_created`, `source_version: 1`. Enqueue only when a persisted intake has an explicit workspace. The existing post-commit `ActivityEvent` remains the immediate view.
- `IntakeScopeRevision` (existing append-only 12-section answers; `version` unique per intake, `author_role` is `client` or `owner`): allowed outbox kind `scope_revision_saved`, `source_version: revision.version`. Both author roles are private to the owner workspace, not client-public. No answer body, prompt, signature or client contact data is copied to `DomainOutboxEvent` or `ActivityEvent.metadata`. The activity title distinguishes only the author *role* and revision number, not content.
- Both models call `DomainOutboxEvent.enqueue_...!` from `after_create` inside the **source database transaction**; when a save rolls back, the event envelope also rolls back. Post-commit `Activity::Recorder` preserves immediate owner UI using the original `Type:id:kind` event key, so a later replayer retry must not produce a duplicate.
- `DomainOutbox::Replayer` resolves only saved sources with `project_intakes.workspace_id == workspace.id`, checks recorded creation timestamp and immutable scope version + author role, invokes only the allowlisted idempotent `Activity::Recorder`, verifies the expected key, and acknowledges. It never writes the canonical intake/scope, bills Grok, posts to clients or sends messages.
- `Activity::Presenter` links the owner-scoped `scope_revision_saved` item to the existing private owner requirements review page. **This is not yet a permalink to an exact historical source version.** E2.4a / C2.3c still needs that version-specific deep-link/UI.
- `ActivityEvent` and `Activity::Recorder` allowlist the new kind and exact scoped subject. RU/EN/HY/ES activity labels added.

## Regression scope
- New workspace-assigned `ProjectIntake` → exactly one outbox and immediate activity; simulate deleted activity in isolated test DB and replay without AI charge; second replay no-op.
- New client and owner `IntakeScopeRevision` versions on one intake → two distinct source IDs and outbox versions; no client answer copied; owner-only source link; another workspace cannot replay/read them.
- A `ProjectIntake` and its scope created in an explicitly rolled-back transaction leave no outbox/activity. An orphan legacy intake with workspace NULL must not be projected at all.
- Explicit foreign owner attempting to record the private scope into its activity index is rejected.
- Historical model tests have their synthetic setup outbox drained to avoid mistaking fixture source events for failures of a later replay.
- Exact-SHA Rails CI/model/controller/Chrome, PG18 fresh+upgrade, Security Audit must be checked **after** this code. If red, fix before marking C2.3b5 CI_VERIFIED.

## Separate local blocker: R0.4
- User's local checkout: `~/rails_calendar_ai_c21c`, short HEAD `c25be48`, `db/schema.rb M`. The owner confirmed Ruby 3.4.13, but `bundle exec rails runner` failed `No version is set for command rails` (asdf shim), not a Postgres error.
- To bypass that *executable shim*, use `ASDF_RUBY_VERSION=3.4.13 ruby bin/rails --version`, then a SELECT-only `ruby bin/rails runner` with `PGOPTIONS=-c default_transaction_read_only=on`. No Gemfile, .tool-versions, project Ruby version, database or server restart has been changed here.
- Read-only `psql` identity already confirmed **`rails_calendar_rc0551f_c21b_review_20261117`**, PG **16.11**, local Unix socket; `domain_outbox_events` does NOT yet exist. Separate Rails-effective DB has not been confirmed; neither port :3002's live connection nor private Active Storage backend has been verified.
- Old backup scripts hardcode another DB, `rails_calendar_mvp_preview_20261112`. Never invoke them for this review database. No DB backup/restoration/migration was authorized or performed; preserve all local files and protected :3001, :3002 and Railway.
- Read `docs/RC0551F_REVIEW_DB_BACKUP_MIGRATION_GATE.md`, validate actual Rails identity, then private backup+scratch restore before any local migration with explicit owner action.

## Remaining checkpoints to production
After exact HEAD CI: C2.3b5 acceptance `CODE_SHA / CI_RUNS / UI / DB / PROD` separately. Then C2.3b6 private bounded health/replay visibility; C2.3b7 dry-run-only backfill; C2.3c source-backed calendar/library/owner notification projections and exact-version links; C2.4 validated AI ActionProposal/preview/human approval/apply and zero-extra-provider-cost derived views; E2.4 12-section R-ID source/criteria/dependency/immutable diff and client-safe vs owner technical views; E2.5 exact bilateral approval; M6/M7 delivery; M8 authorized staged production release.
