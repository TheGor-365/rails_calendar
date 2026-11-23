# Rails Calendar / White Atlas — PRODUCT-FIRST delivery plan

**Decision checkpoint: 2026-11-23 | Owner-requested change of priority.**
**STATUS: PROPOSED IMPLEMENTATION PRIORITIES FOR OWNER REVIEW, NOT FEATURE ACCEPTANCE OR PRODUCTION RELEASE.**
Reference: [original production-MVP roadmap](RAILS_CALENDAR_MVP_EXECUTION_ROADMAP.md); [latest evidence](RAILS_CALENDAR_EXECUTION_STATUS.md). This plan is an execution overlay; it does not erase or falsely close R0, G5/G6, M8, privacy, security or user consent.

## 1. What materially changed in priority

The previous thread over-optimized for scratch PostgreSQL metadata and historical backfill safeguards. Those are necessary for replaying legacy six-family events and any migrations/recovery affecting valuable data, but NOT a reason to indefinitely postpone:
- Existing owner/client UI feature completion, targeted fixes and manually verified local browser UX;
- Owner AI conversation and existing four permitted assistant operations using mock providers, with separately consented **single** real xAI call once ready;
- An end-to-end persisted test client journey on isolated test data;
- A separately managed staging/release candidate for selected already-verified functionality.

**Work allocation target, not measured time or a deadline:** Product/AI/funnel ~65%; browser QA and release packaging ~25%; safety/infra debt ~10% until a specific release gate requires more. Avoid further metadata micro-gates just to advance an independent UI screen. No speculative multi-hour maintenance loops.

## 2. Source truth as of 2026-11-23

- GitHub Draft PR #81 HEAD `2cc62619b4b74bcb9709a67033e4b10ebb2b9d82` at initial plan review; all four exact-SHA Rails CI and Security Audit completed SUCCESS. This is code/CI evidence, NOT human browser acceptance or production.
- The production Railway project `rails-calendar-ai-workspace`, service `rails-calendar-ai-web`, is set to `feat/client-owner-pilot-2026-11-13`, latest deployed SHA `90d7a817651ba1bffe174d3f800d32988a664169` from 2026-11-13 and deployment state `SLEEPING` when read. Production domain: `rails-calendar-ai-web-production.up.railway.app`. PostgreSQL 18 production service and persistent 5,000MB `postgres-volume` exist. No changes made. GitHub Compare indicates 1,166 commits from deployed SHA to current stacked PR head, not a reviewed release delta. Do **not** deploy or merge this entire stack without a scoped compatibility and data plan.
- Code routes currently include `/workspace/assistant/conversations`, `/workspace/assistant`, `/workspace/services`, `/workspace/invitations`, `/workspace/activity`, `/workspace/library`, `/client/requests/new`, `/client/requests/:id`, `/workspace/outbox/health` and calendar day/hour. Presence of route != browser-accepted or deployed.
- C2.1c owner AI conversation code includes one explicit consented xAI Responses turn, strict JSON, account budget/ledger and uncertain handling, but no real provider expense/answer or local owner browser signoff is evidenced. Existing owner AI operations: `service_copy`, `intake_questions`, `client_reply`, `plan_outline`; do not invent more working capabilities.
- C2.3b source/outbox adapters and dry-run/health tooling are extensively coded. Owner R0.4 historical scratch archive/media/metadata and scoped Active Storage aggregate reviews gave partial positive evidence, **not** full G4/G5/G6. C2.3b7s prior read permission was consumed. Historical backfill/replay (G7) and source/production migrations stay unauthorized.
- New C2.3b7t static schema contract covers 17 tables/94 selected columns, but owner scratch typed catalog has NOT been queried. No reason to block isolated code and visual work over this.

## 3. Delivery cadence: small user-visible verticals, one proof per slice

Each slice is a coherent path `page → user action → persisted state → return/reload → permission check → screenshot → exact commit/CI`. Mark statuses separately: `CODE`, `AUTOMATED_CI`, `OWNER_BROWSER`, `STAGING`, `RAILWAY_PRODUCTION`, `REAL_AI_COST`, `REAL_CLIENT`. Never upgrade status without evidence.

### F0 — immediate next step: release-focused local baseline and browser walkthrough
**Goal:** resume working functionality immediately; no database archaeology as a prerequisite.
- Select a **new separate clean checkout/worktree** for the intended feature SHA; inspect current owner-local runtime, exact Rails effective dev/test database identity and app processes; preserve existing dirty `~/rails_calendar_ai_c21c/db/schema.rb`, restored scratch and all older worktrees. Do not run `db:prepare`, migrate or reset on valuable review DBs. Synthetic/test-only DB can be prepared after explicit target check.
- Execute a short local owner-browser proof on an already implemented route: owner login → `/workspace/assistant/conversations` → new conversation/saved note → reload, then `/workspace/services`. Take 1440 and 390 width screenshots and one negative client/guest view. Only 1–3 user actions per checkpoint; fix the first reproducible blocker, then return to workflow.
- Triage previously intermittent `OwnerServiceMediaBrowserTest`: predecessor 5da06fb PR Rails CI failed one browser test after media approval with empty Reviewed text; same SHA push CI and next SHA 2cc6261 all CI passed. Root cause NOT established. Reproduce targeted test/interaction; avoid speculative CSS changes.
**Exit:** exact SHA runs, owner manually confirms real pages, screenshot/browser outcome recorded. No paid AI necessary in F0.

### F1 — owner AI conversation: first genuinely working AI capability
**Goal:** a saved conversation with one clearly consented real answer; no fake tokens, costs or success.
- Use existing C2.1c owner-only conversations / xAI structured output / existing `AiSpendLedger`, not a new chat engine.
- Verify free saved notes, new thread, locale, rename, reload, archive, persistent past AI turns; verify idempotent form UUID, disabled provider/budget and uncertain state in isolated tests.
- Mock-first browser smoke for input/render/refresh/mobile 1440/390/320. If setup is ready, request **separate explicit owner approval** for ONE real paid xAI Responses turn with sanitized prompt and preset budget; only then verify true response saved, ledger settled/uncertain, no duplicate charge. A second paid follow-up is separate permission.
- No automatic client/customer data in provider context, no arbitrary tools, no auto retry after uncertain result.
**Exit:** real browser owner acceptance + controlled paid provider evidence (if independently authorized), stored response and correct ledger; production deployment separate.

### F2 — service offer → invitation → client request (first commercial funnel)
**Goal:** complete one fictional end-to-end order with no lost data.
- Verify existing service catalogue draft/approval/publish and private media moderation; only real published versions become selectable.
- Owner creates a scoped invitation or verified client starts `/client/requests/new`; client registers/verifies/claims and submits one canonical `ProjectIntake`. Preserve existing E1/E2.1–E2.3 code; fill only proven gaps.
- Ensure draft/autosave on reload, wrong-owner/guest denial, one-time invite TTL/revoke, choices 0–6, unknown options, idempotent claims and safe no-public URL disclosure.
- Browser test one owner + one synthetic verified client at 1440/390/320; visible owner inbox/unread and return link. No real SMS/email claims unless an actual delivery integration exists.
**Exit:** recorded source ID/versions kept private, UI screenshot proof, CI and role checks; measure one fictional lead → submitted intake.

### F3 — C2.4 AI Action Engine, beginning with existing service/client copy flow
**Goal:** AI assists an actual owner task, rather than only describing it.
- Start with existing `service_copy` and `intake_questions` operations, then owner-selected `client_reply` and `plan_outline` when matching targets exist. Do not expose nonimplemented tools.
- Strict allowlist + schema; source-version digest, proposal with evidence/risk, side-by-side before/after, explicit accept/edit/reject, conflict/stale revision block, persisted audit. No auto-publish, no direct provider-to-DB arbitrary writes.
- One approved change updates its canonical source; client/calendar/library/inbox show only authorized deterministic projections. Reads/replays must not invoke a paid model again.
**Exit:** synthetic AI suggestion → owner-confirmed versioned change → persisted visible result in expected page(s); role/cost tests PASS.

### F4 — E2.4/E2.5 spec package and two-sided review
**Goal:** convert submitted intake into actionable versioned work scope, not another disconnected form.
- Owner constructs 12-section spec with exact answers/provenance, R-IDs, risks/unknown/exclusions and acceptance criteria. Keep client-safe and technical owner views separate.
- Immutable v1/v2 diff and change request; exact-version owner approval followed by independent client approve/request changes. No implicit contract/legal signature.
- Private export (TXT/Markdown first; PDF only after ACL/retention/format QA); links should lead to actual generated files, not placeholder buttons.
**Exit:** one fictional intake → shared reviewed exact spec digest → explicit two-sided approval/change request without loss or leakage.

### F5 — M6/M7 projects, tasks and delivery evidence
**Goal:** take an approved spec through a work item and deliverable.
- Create project/milestones/tasks only from approved scope with explicit owner action; each task has R-ID links, deadline semantics and status/owner ACL.
- Attach actual file/commit/test link, private proof, review and client acceptance/change request; produce a reusable handoff summary.
- Calendar projections are derived from persisted milestones/events and may not fabricate scheduled dates.
**Exit:** one fictional test client passes request → spec → task → deliverable → reviewed acceptance on an isolated environment. Later one consented real-client pilot.

## 4. Parallel release track: Railway in small, reversible increments

**Never deploy feature PR #81 wholesale merely because it is green.** Before production:
1. Build a **release gap inventory** from running SHA `90d7a817` vs intended candidate, grouped by feature, schema migration, Active Storage, API/provider, auth/ACL, UI assets and dependency/runtime changes. 1,166 commits of stacked development demand reduction to reviewed vertical release sets, not a blind cherry-pick list.
2. Use a separate staging/test target with **isolated DB/storage and test credentials**, or an independently verified disposable local staging environment first. Creating Railway resources or enabling chargeable services requires owner approval. No copying production client rows or unreviewed secrets.
3. Each release candidate: versioned migrations rehearsal on isolated DB, schema compatibility/rollback, exact SHA CI & Security, owner/client/guest browser screenshots, provider default-off, private media check, migration and rollback plan. Production backup + recovery proof must cover **actual deployed PG18 and storage**, not simply historical local PG16 R0.4.
4. Only after owner explicitly authorizes branch/SHA/target/migrations: staged deploy → smoke tests (login, service, invitation, client request, AI default-off, existing data unchanged) → controlled production release. Observe actual Railway deployment status and app URL; `SLEEPING` is not evidence of live HTTP acceptance.
5. Subsequent **release trains** are small and independently reviewable: **R1** stable existing owner/client shell and pilot interactions; **R2** owner AI chat behind verified owner auth and budget limits; **R3** client intake + service catalogue + persistence; **R4** AI proposal/apply and versioned specs; **R5** projects/delivery. G5/G6 full only gate the specific source-row historical backfill/repair/supervised replay and the relevant production write/migration boundaries; they do not stop unrelated local UI development. No deploying migrated-source-only screens to an older incompatible database.

## 5. Browser acceptance and AI verification protocol

Browser checks are not deferred to “after infrastructure”. For every visible feature:
- Real owner session: desktop 1440, mobile 390 and 320; reload, Turbo navigation, browser back, validation errors and keyboard focus. Confirm no horizontal scrolling or hidden required action.
- Second synthetic client and unauthenticated guest: own record visible, foreign owner's record not accessible; expired invitation/replayed submit blocked; test evidence has no live IDs/secrets.
- No real provider call in automatic CI. Mock verifies schema, budget, consent, dedup, uncertain case and privacy; one **owner-consented** real xAI call proves external integration separately.
- User clicks/screenshots one page at a time. Record exact SHA, page, viewport, role, action and screenshot verdict. For CI failure, inspect exact failure log and reproduce only target; don't blindly rework unrelated UI.
- Production proof must be collected from published URL and Railway deployment SHA after authorized release, not from localhost or GitHub Actions.

## 6. Weekly work-budget policy and handoff

Prioritize tangible funnel outcomes rather than number of commits/diagnostic gates.
- Product focus ~65%, real browser QA and release extraction ~25%, infrastructure/risk-specific gates ~10%. Ratios are allocation goals, not guaranteed time estimates.
- Avoid five small gating PRs when one targeted feature+test is feasible. Keep each change a coherent vertical slice, with 1–3 user terminal/browser actions before a check-in. Prefer code+CI+browser+checkpoint in same work unit.
- End every functional unit by updating `docs/RAILS_CALENDAR_EXECUTION_STATUS.md` with CODE/CI/BROWSER/STAGING/PRODUCTION/PAID status separately, and a PR comment. Never claim cross-chat repo state without connector readback.
- Work on independent functional code/UI immediately, while a separate owner-approved operations track resolves real G5/G6 blockers needed for historical replay and deployment. No repeated querying of valuable source/scratch or renewed approvals by inertia.

## 7. Immediate next actions (no new historical DB reads)

1. Select first product slice **F0/F1**: new clean separate feature checkout at known SHA, local runtime verification, existing owner chat page and service catalogue browser acceptance; preserve old dirty worktrees and databases. Operator instructions limited to exact environment/current output and 1–3 actions.
2. Implement/fix the **first demonstrable functional defect** from browser walkthrough, or if already functional, proceed directly to mock-AI then separately consented real AI turn. Record screenshot and exact CI.
3. In parallel prepare a **minimal safe Railway R1 release-gap inventory** and candidate plan for user review, without changing Railway settings, creating resources or deploying.

**Next session starts with UI/AI functionality — NOT C2.3b7u metadata, not replay/restore, not a new scratch-db gate.**
