# C2.3 — Canonical activity source, versioned events and commercial flow
Date: 2026-11-21. Scope: Rails Calendar / White Atlas. PR #81 (Draft).

## Operator evidence
- The owner installed Ruby 3.4.13 into `~/.asdf/installs/ruby/3.4.13` after updating the asdf plugin; `ruby -v` in the same shell still reports **3.4.12**. Inspect `asdf current ruby`, `asdf exec ruby -v`, PATH and per-project version selection before restarting localhost :3002. Do not alter global versions for unrelated projects.
- Owner local `db/schema.rb` remains modified. No restore/reset/clean or new migration was authorized.
- Baseline `ecc0552` CI: model/controller Rails 358/5963 PASS, PostgreSQL 18 clean/upgrade PASS, security PASS, 1 Chrome system failure in unrelated White Atlas spec workbench anchor navigation. This requires separate UI verification.
- Existing `Activity::Recorder`, `ActivityEvent`, `Activity::Presenter`, `Calendar::OwnerActivity`, `OwnerArtifactsController` are canonical groundwork. Do not replace their source models.

## C2.3a implemented (no schema change, no provider call)
1. `Activity::Recorder.record!(revision: N)` can now index repeated source versions as `Type:id:kind:vN`; legacy callers keep `Type:id:kind` unchanged. It ignores duplicate revisions through the existing PostgreSQL unique index. Input/owner guards enforce allowed event kind, source tenancy, positive revision, allowlisted metadata and <=512 metadata bytes.
2. `Activity::SourceLinks.ai_conversation_path` resolves a settled `OwnerAi::ConversationResponder` spend entry to the *original* conversation only if a saved settled assistant message uses that ledger and matches the exact workspace. No URL from provider JSON is trusted; mismatches and missing/removed sources return nil.
3. `Activity::Presenter` reuses that path for AI-settled activity calendar and notification events; `OwnerArtifactsController` reuses it for the same record in the owner library. Rendering these views is read-only: no second AI invocation and no additional ledger entries.
4. Existing integration suite extended: distinct versions, duplicate retries, legacy compatibility, cross-owner deny, metadata deny, exact AI source across journal/calendar/library, other-owner absence and no writes on GET.

**Important limitation:** This does **not** implement a universal outbox, background delivery, generated files, automatic page mutation or client-facing publication. It links existing saved, paid AI outputs through deterministic source lookup. CI/Security result must be verified for the final exact SHA before marking accepted.

## Next vertical slices
### C2.3b — durable, replayable source updates
- Design and separately approve transactional `domain_outbox_events`: workspace, immutable source type/id/version, kind, actor, visibility, correlation ID, processing status, UNIQUE(workspace,source,version,kind).
- Integrate canonical write + outbox in the same DB transaction. Reconciler replays missed events with bounded batching, backoff and dry run, never a new paid model call.
- Project/read models render context appropriate to owner, verified client, guest. Keep private client body and AI prompts OUT of event metadata.
- Test duplicate delivery, reversed arrival, stale versions, cross-owner isolation, crash after commit and recovery, PG18 migration/rollback.

### C2.3c — deterministic multi-surface projections
- Calendar separates `occurred_at` from future scheduled work, links to exact source; library indexes real existing saved artifacts; inbox read receipts remain owner-specific; later project/task feeds consume the same event.
- Measure projection lag, missed source count, duplicate count and authorized navigation coverage.

### C2.4 — AI action proposal + controlled apply
- One explicit consented paid request produces a strictly validated proposed JSON action with target, source version, diff, evidence, preconditions and cost ledger ref.
- Owner reviews affected objects and applies only allowlisted operations transactionally; publish/approve/delete/deploy always require explicit human confirmation. No arbitrary SQL/JS/file writes by provider output.
- One saved source revision → many deterministic projections without recharging.

### E2.4 → E2.5 → M6–M8
- 12-section client scope with stable R-ID, exact provenance, status and acceptance criteria, exclusions/dependencies, immutable v1/v2/v3 diff, separate owner-technical and client-safe views.
- Independent bilateral approval on an exact immutable spec digest; change requests create new revision; projects/tasks/milestones, files/checksums/tests/delivery and human acceptance follow.
- Railway release requires stacked PR integration, exact SHA CI/Security, private storage and backup+restore, visual 320/390/1440, Ruby 3.4.13 production patch and owner authorization.

## Operator next actions
1. `cd ~/rails_calendar_ai_c21c && asdf current ruby && asdf reshim ruby 3.4.13 && asdf exec ruby -v && type -a ruby && ruby -v`.
2. After verified CI and correct runtime, safe `git status --short` and `git pull --ff-only origin feat/rc0551f-c21c-live-owner-ai-chat-2026-11-18`; preserve modified schema.
3. On :3002 confirm synthetic source AI turn opens exact owner conversation from month/day/hour/activity journal/library and is absent for other owner/client; no paid AI calls.

## Status
CODE committed to stacked Draft PR, no main merge or Railway changes. New exact SHA checks pending until observed. Local Ruby selected version and browser sign-off not yet verified.
