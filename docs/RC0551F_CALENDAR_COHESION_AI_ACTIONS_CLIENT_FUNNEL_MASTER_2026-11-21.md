# Rails Calendar / White Atlas — calendar cohesion → applied AI → client funnel
Date: 2026-11-21. Status: executable development plan, not production approval.

## Verified baseline and boundaries
- Current work: stacked Draft PR #81, `feat/rc0551f-c21c-live-owner-ai-chat-2026-11-18`. The owner's Linux checkout had fast-forwarded to `c25be48`; `db/schema.rb` remains modified locally. Latest feature branch continues beyond it. Local Ruby 3.4.12 cannot run the updated Gemfile pinned to 3.4.13; owner must update `asdf-ruby` and install 3.4.13. Existing :3002 is a running older process, not evidence that the new head is running.
- Four supplied browser screenshots: owner calendar month shows `owner_ai_chat_v1` on 2026-11-18 at 17:33, owner day screenshot shows first hours (00–10) and "0 consultations", client cabinet has two fictional requests, invite preview displays a fictional contact-form discovery questionnaire.
- Current `PagesController` month projects consultations + `Calendar::OwnerActivity`. Day already fetches owner activity and renders collapsible hour overlays (only below the fold at 17:00); prior day/hour counters and empty state referred only to consultations. `Activity::Recorder` writes an owner-scoped append-only event index; `Activity::Presenter` allowlists destination paths; `OwnerArtifactsController` serves private source-backed exports. These are the foundation, not components to rebuild.
- Old Railway production web service is on a different branch; no deployment, main merge, DB reset/migration, token access or paid AI invocation in this slice.

## P0. Current vertical slice: month → day → hour → source (C2.2)
1. Correct combined counts across the three levels. Consultations span hours; owner activities occur at a point in time. Count each source once per day and in the matching hour, without duplicating a consultation that overlaps adjacent slots in the day total.
2. Display activity recap *above* the 24-hour grid, with time, localized kind/status, a link to the hour and a link to the canonical source. Keep original 24-hour time blocks and consultation overlap layout; allow accordion drill-down within the hour.
3. Month grid: visible day boundaries, distinct past/today/future backgrounds, legible numeric badges and event cards. Day and hour: past AI chats/actions visually subdued but readable, current hour and future distinct; no invented activity in empty slots.
4. Owner-only activity and destinations must never leak to guest, client or another owner's workspace. Legacy orphan intakes are never assigned implicitly. Direct AI conversation links must be workspace-scoped.
5. Display human-readable translations RU/EN/HY/ES. At 320, 390, 768 and 1440 px preserve click targets, keyboard focus and no horizontal overflow.
6. Prove with Rails model/controller tests, Chrome system tests, PG18 fresh + deployed-baseline upgrade and Security Audit on the **same commit SHA**. Owner must inspect local screenshots before acceptance.

DoD P0: On 2026-11-18, the calendar event at 17:33 is visible in day recap without scrolling 17 hours, appears in the 17:00 hour, and opens the exact owner AI source when authorized. Empty consultation count no longer claims day/hour has no activities. No unexpected writes on read. Exact-SHA CI green, human UI sign-off pending.

## P1. Authoritative events and cross-surface propagation ("one save, many projections")
- Map each domain mutation and generated artifact to an owner-scoped canonical source: `source_type/source_id`, `workspace_id`, `source_revision`, `occurred_at`, `created_by`, `visibility`, `kind`, `correlation_id`, `idempotency_key`, and optional parent project/intake/conversation. Personal or client content must not be copied into event metadata.
- Mutations pass through an explicit application service with a transaction and event/outbox commit. The next safe implementation should extend the existing `Activity::Recorder` instead of replacing authoritative models.
- Event keys need to support *repeated revisions* (the current `subject class:id:kind` key only records one event of each kind per subject). A versioned source event ledger/outbox, with unique `workspace/source/version/kind`, is required before auto-propagation of recurring AI messages and task edits.
- Create read-only projectors for Calendar, Library, Owner notifications, Project, Task/Delivery, Client-approved view and analytics. They consume the same source ID/version and never generate separate paid model requests merely for rendering.
- Rebuild/backfill projections from durable records, use idempotent retries, include traceable source links and event ordering. Cross-tenant or private artifacts stay private by default; never emit token, full prompts, documents or client PII into public feeds.

DoD P1: one synthetic saved AI artifact appears in the correct owner activity timeline, indexed library record and applicable project context; the event is not duplicated after retries; forbidden roles cannot read sources; no extra provider charges.

## P2. AI results as actionable changes, not unstructured conversation
- One explicit consented/budgeted model call returns a typed, schema-validated `ActionProposal`: `operation`, `source_refs`, `target_type/id`, `proposed_patch`, `assumptions`, `confidence`, `cost`, `required_confirmation`.
- Never trust model text as SQL or action instructions; allowlist target actions and validate ownership, version/preconditions, input length, source and cross-tenant references.
- Preview the exact before/after diff, affected pages, files and cost *before* apply. Low-risk user-enabled auto-apply may be configured later per action; approvals, publication, destructive actions, customer-facing commitments, financial/legal updates and deployment always need an explicit human gate.
- Apply a validated proposal atomically to source records (or fail without partial mutation), record immutable revision + event, then update all deterministic projections. Failed/raced/stale proposals remain visible for correction; model cost is recorded once even when application fails.
- File generation is an actual persisted private artifact with supported MIME/size, version, checksum, owner ACL, preview and controlled download—not a fictitious link or silently created local file.

DoD P2: one billed AI call → one reviewed source revision → several synchronized, readable surfaces with one cost entry and clear rollback/new-revision process. No extra AI charges for the projections.

## P3. Client discovery → 12-section structured technical specification (E2.4)
Existing source models: `ProjectIntake`, `IntakeScopeRevision`, `IntakeRequirementSet`, `IntakeSpecVersion`. Reuse them. A client scope snapshot is not already mutually approved.

Sections (same order as product specification):
1. Business goal and context.
2. Audiences and roles.
3. Pages and user journeys.
4. Functional requirements.
5. Data and integrations.
6. Nonfunctional requirements.
7. Materials, content and design.
8. Acceptance criteria.
9. Constraints and exclusions.
10. Risks, dependencies and unknowns.
11. Proposed task breakdown.
12. Nonbinding preliminary estimate.

Each R-ID row requires stable identity, precise source `scope_revision_id/section` plus source question/answer/version where truly recorded, clear statement, status `confirmed/suggested/unknown/excluded` with the *actor* and provenance, independently verifiable acceptance criteria, dependency links and exclusions. A client's "confirmed" response is not bilateral owner/client approval.
- E2.3 already has manual R-ID editing, criteria, append-only revision history. E2.4c adds immutable R-ID diffs (do not rebuild).
- Next: E2.4a exact answer provenance and owner-only source navigation; E2.4b dependency graph, cycle detection, unresolved exclusions; E2.4d distinct client-safe scope vs developer technical implementation notes. Track source changes that invalidate a previously derived version.
- AI suggestions and estimated cost/timeline stay explicitly unapproved until owner review. No blind rewriting of client-authored words.

DoD P3: answer → exact R-ID and version → immutable v1/v2/v3 diff and client/technical views; no cross-account access; missing acceptance and unknowns clearly exposed.

## P4. E2.5 bilateral approval and operational workflow
- Owner approves an immutable, hashed spec version and its scope/exclusions/assumptions; client receives *that* version only and can approve or request changes; any change creates a new draft, never overwrites an approved one.
- Record independent actor identity, timestamp, version ID, change request and audit trail. Do not present a draft/reviewed flag as a signed legal agreement.
- With explicit authorization turn approved milestones into project/tasks, assign estimates and calendar anchors, link tests/files/deliverables, support client feedback and final acceptance.
- Clearly separate private owner AI assistance, paid expenses and internal notes from client-visible deliverables.

DoD P4: verified client invitation → structured answers → reviewed R-IDs → exact dual-approved version → visible scoped tasks/calendar/milestones → delivery and documented acceptance.

## P5. Release and commercial validation
1. Full stacked branch integration and conflict-free tested target; backup and *restore test* of PostgreSQL 18 and private files, durable private storage, KYC/payment/compliance unrelated to this feature.
2. Strict ACL/IDOR, CSRF, XSS, redirects, file access, PII/consent, caching, AI cost/quota, retry/double-apply, source deletion/unavailability, browser mobile/desktop and operational monitoring.
3. Exact SHA CI/Security green; explicit production authorization; separate safe Railway deployment gate. Current production Ruby 3.4.12 must be patched before inviting real clients.
4. Commercial KPIs: qualified lead → completed scope → mutually approved specification → funded task → delivered, accepted work → actual accessible payout. Do not count AI chats or postings as revenue.

## Immediate handoff
- Developer/assistant: complete C2.2 in Draft PR #81, exact-SHA tests, update GitHub/Drive/Notion/ClickUp with evidence, no Railway changes.
- Owner local Linux: `asdf plugin update ruby`; if stale `ASDF_RUBY_BUILD_VERSION=master asdf install ruby 3.4.13`; verify `ruby -v`, `bundle -v`, `git status --short`. Preserve locally modified `db/schema.rb`. After exact-SHA CI and owner confirmation, fast-forward latest branch and view `:3002` month/day/hour/library screenshots.
- Acceptance pause: do not begin customer-facing live funnel while client data/privacy, persistent files and production release gates remain unverified.

## Known non-goals of C2.2
No AI call, no auto-publish, no creation of client deliverables, no broad data backfill, no lifecycle model rewrite, no full "AI modifies any screen" implementation yet, no change to original local port 3001.
