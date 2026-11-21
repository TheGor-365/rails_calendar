# Rails Calendar C2.3b — transactional outbox and bounded replay
Date: 2026-11-21. Scope: Draft PR #81, owner-private fictional pilot, no production deploy.

## Reused authoritative components
- `IntakeRequirementSet` is immutable per version and belongs to a scoped `ProjectIntake` and `IntakeScopeRevision`.
- `ActivityEvent`, `Activity::Recorder` and `Activity::Presenter` remain read-only owner activity projections. Existing event keys and read receipts remain unchanged.
- `AiSpendEntry` remains the single ledger for AI usage. Rendering/replay never calls a provider, touches its ledger, or sends mail.

## First implemented transaction-safe source
1. Migration `20261121003000_create_domain_outbox_events.rb` adds an indexed, private `domain_outbox_events` table with `workspace_id`, source type/id/version, kind, state, attempts, occurrence/delivery/next-attempt timestamps and restricted error class only. Unique `(workspace_id, source_type, source_id, source_version, kind)`; status and positive-value database checks. Stores NO prompts, answer text, client documents, tokens or provider URLs.
2. A freshly saved `IntakeRequirementSet` queues its corresponding outbox row in the **same database transaction** (synchronous `after_create`), so a rollback removes both. The existing `after_create_commit` immediate activity event remains active temporarily for backward-compatible calendar UX; both legacy projection and replay use the SAME idempotent `Type:id:requirements_saved` key.
3. `DomainOutbox::Replayer.run!(workspace:, limit: 1..100)` explicitly reads only due entries from one workspace, locks records before handling, resolves only allowed immutable requirement versions in that same workspace, emits missing activity events via `Activity::Recorder`, verifies the resulting key, then marks the envelope delivered.
4. A replay of an already-recorded legacy event simply marks the outbox delivered and does not duplicate timeline events. Replays never call models or user-facing client publication endpoints.
5. Failures record only exception class, capped attempts 5 and exponential retry delay (up to 3600 seconds). Missing or foreign sources cannot be resolved through arbitrary class constantization. This is a **manual internal service**: NO scheduler, worker, request route, deploy or paid call is enabled.
6. New synthetic tests exercise atomic enqueue/rollback, lost-activity recovery, second replay no-op, cross-tenant non-delivery, missing-source retry/failure and unmodified AI cost ledger.

## Next sequence (not implemented in this first slice)
- Validate CI Rails/controller/Chrome, PG18 fresh migration and isolated deployed-SHA upgrade, Security on EXACT latest SHA. Tests are only accepted when returned SUCCESS.
- Approve a source-by-source migration plan for `OwnerAiMessage`, `AiSpendEntry`, `ClientRequestInvitation`, `ServiceOfferingVersion`, `ProjectIntake` and immutable client scope; each source must enqueue within its canonical transaction, with source/version/operation mapping and denial of client PII. Do not bulk-enable automatically.
- Build a safe internal operator queue/dashboard (owner-only, no prompt export), observe pending/failed/lag metrics, and a bounded worker/scheduler with explicit consent; reconcile missing legacy records in dry-run mode first.
- Revisit duplicate event delivery, ordering, reconciling source deletion, and transactional guarantees when adding external consumers. Correctness of a *single* event ledger does not yet guarantee consistency of every target page.
- C2.3c deterministic per-surface projections to calendar, library, owner notifications, task context, then C2.4 strict human-reviewed AI ActionProposal; later 12-section R-ID client discovery and exact-version two-party approval.

## Safe migration/release gate
- **Do not run this migration on the user's currently running local development DB or Railway** as part of this chat.
- `db/schema.rb` is locally modified; do not reset/stash/overwrite. CI runs new migration only on isolated PostgreSQL test instances. Create/verify independent backup before any later local migration and confirm the actual target via `SELECT current_database(), inet_server_addr()`.
- The local shell currently overrides Ruby selection with `ASDF_RUBY_VERSION=3.4.12`; use `export ASDF_RUBY_VERSION=3.4.13` in that terminal and verify before a Rails process restart.
- Draft PR #81 remains unmerged, and old Railway production still uses separate, vulnerable Ruby 3.4.12 baseline until an authorized patch/release.
- All acceptance results must be documented with exact commit SHA and GitHub workflow URLs; no AI provider calls or production mutations for this slice.

## Explicit non-goals
This is an initial durable event contract for immutable requirement revisions, not a complete universal outbox, not a projection engine for all AI-created content, not a background job release, and not human/contractual approval of client requirements.
