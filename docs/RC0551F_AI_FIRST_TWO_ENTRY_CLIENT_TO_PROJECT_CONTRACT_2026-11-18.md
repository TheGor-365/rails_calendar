# Rails Calendar / White Atlas — AI-first two-entry client-to-delivery contract
**Date:** 2026-11-18  
**Purpose:** Implementation blueprint for the first two business workflows, contextual AI, a reusable project-memory layer and human-controlled client↔owner acceptance.  
**Status:** SPECIFICATION, not a claim that these flows exist. C2.1c owner dialogue is live-tested once by owner; C2.1d Turbo/attachments is currently under CI. Existing owner/client cabinets, synthetic intake, service offerings, approved specs, consultations and initial milestones must be reused, not cloned.  
**Source:** owner screenshots and 2026-11-18 detailed requirements + 2026-11-08 AI Service Workspace master plan.

## 1. Product goals and non-negotiable rules

- **One customer can own multiple requests/projects, one owner can serve multiple customers.** Every AI call, draft, file, notification and event is attached to an explicit audience/context and visible provenance.
- Two **equivalent** starts converge on one canonical `ProjectIntake` (later `Project`), rather than creating two incompatible order types:
  1. Client independently chooses one or several **published** services, or starts with a free-form task (possibly asking AI about the specialist first).
  2. Owner first creates a proposal/seed from off-platform discussion and sends a time-limited invitation; recipient registers/verifies, **claims** the proposal, edits it with AI, then submits it as their request.
- **No automatic legal agreement, price, booked calendar event, customer message or payment**. An in-app scope agreement is a versioned two-party confirmation of requirements and delivery conditions, labelled explicitly non-legal.
- AI generates and edits **proposals** with source IDs, assumptions and uncertainty; Rails validates and humans confirm. No claims of executed tests or accepted work without evidence.
- Owner-only strategic context, capacity, internal rate, buffers, workload, private assistant chats and unseen client requests **never reach client AI context or client screens**. Client gets approved scope and deliberately public status/ETA.
- **No prompt injection escalation:** source text, attachments and web content are untrusted; tool/action authorization lives in Rails. No tool call from M1. Future browsing/knowledge tools require per-action scopes, budgets, allowlists and auditable citations.
- The current verified-client request flow is **local fictional pilot** and is not yet a public real-data intake. Do not remove its gate to demo a feature.
- Credentials never requested in AI chat/forms; safe descriptions, access checklist and secure delegated connections are separate.

## 2. Role and context map

| Identity | Entry surface | Allowed AI context | Explicitly forbidden |
|---|---|---|---|
| Guest (unregistered) | Public services, read-only portfolio, optional consented pre-intake | Published service version, sanitized public practice info, transient own inputs | Any private customer/workspace/project data; durable personal history before consent |
| Verified client | Client cabinet, own request drafts and project rooms | Self-authored answers, chosen published service version, own spec, own project status | Other clients, internal owner estimates and work schedule, unpublished supplier notes |
| Owner | Workspace, AI private studio, intake inbox, project room, planning | Approved own practice, authorized client request, work policies, owned projects/calendar | Other workspace/tenant records, hidden secrets, unconsented external uploads |
| Future manager/developer | Assigned project workspace only | Assignment-specific approved scope, files and tasks | Global owner private strategy and unrelated clients |

**Canonical AIContext envelope (validated server-side, not client-supplied authority):**
```json
{
  "actor_user_id": "authenticated_only",
  "role": "owner|client|guest",
  "workspace_id": "authorized_workspace",
  "client_user_id": "authorized_client_or_null",
  "project_intake_id": "authorized_intake_or_null",
  "project_id": "authorized_project_or_null",
  "scope": "owner_general|client_pre_intake|intake|spec|project|task|calendar",
  "scope_revision_id": "version_or_null",
  "conversation_id": "scope_owned_id",
  "locale": "ru|en|hy|es",
  "visibility": "private_owner|private_client|shared_approved",
  "source_refs": ["visible_versioned_records_only"]
}
```
No request parameter is trusted as tenancy proof. Every server read traverses an authenticated relationship, e.g. `current_user.client_project_intakes.find(...)` or `current_user.owner_workspace...`. A vector index or external retrieval connector must enforce **exact same filtering** before results can be included.

**Knowledge source tiers:**
1. Deterministic approved question/answer catalog, business rules, public service version and scope taxonomy.
2. Authored canonical records: typed client selections, owner corrections, versioned spec requirements, accepted milestones, approved media and safe attachments.
3. Auditable AI-generated suggestion snapshots with model/prompt/context version and citations/provenance.
4. Explicitly enabled external docs/web research; output marked third-party, timestamped with source URL, not accepted requirement.

For each AI reply, assemble a **bounded snapshot** with exact active object ID/version and limited recent turns for *that scope*, never the entire global message store. Separate owner-private "workbench" conversation from shared client↔owner thread, even when they discuss the same project.

## 3. Journey A — client self-service or free task, no manual long questionnaire

### A0. Public entry
- On `/services`: cards from **published** `ServiceOfferingVersion` only, never draft/private offerings. Buttons `Choose`, multi-select service checklist, `I need another task`, `Ask about the specialist`.
- If guest: read-only public Q&A can answer public portfolio and service questions, mark AI-generated content clearly; do not save arbitrary personal data before consent. Durable intake begins only after verified account and approved privacy/legal release gate.
- Selected services are **references to immutable published versions**, not plain titles. Show scope/exclusions and explicit warning when mixing incompatible services.

### A1. Client cabinet / request builder
**Top:** title `New request`, step indicator `Brief → Clarify → Review → Submit`, service chips, `Change selections`.  
**Main:** multiple selectable service cards (optionally empty), adaptive cards for goals / audience / feature necessity (MVP / later), budget range and desired dates, each with `Don't know` and `Custom answer`; plain-language explanation of why each question matters.  
**Bottom:** persistent `Save draft`, `Ask AI to explain`, `Next question`; side summary updates after each choice. **No automatic paid call on every keystroke.**  
**AI when asked:** uses published service facts and current confirmed answers only, proposes next single question/options and short explanations. `question_id`, `answer_revision`, evidence/source, state `confirmed|suggested|unknown|excluded`.

**Canonical persistence:** existing `ProjectIntake` + existing `IntakeAnswer` revisions, plus a separate immutable selected-service-version join when implemented. Client can edit own draft before submission; after submission changes create a new revision/change request, never silent overwrite.

### A2. Qualification and spec
AI synthesizes a multi-section spec with each requirement `R-001` etc., source `answer_revision_id` and state:
1. Business purpose/context
2. Audience/roles
3. Pages/user journeys
4. Functional scope
5. Data/integrations
6. Non-functional constraints
7. Design/content/assets
8. Acceptance tests
9. Exclusions
10. Risks/dependencies/unknowns
11. Suggested tasks
12. Preliminary estimates (no binding promise)

At the end of `Review`, client edits every section, then `Submit request` creates a versioned customer-origin proposal; owner receives scoped inbox notification. Client never sees owner-private AI technical notes. Owner reviews and returns an **approved draft version** with explicit corrections.

## 4. Journey B — owner sends a scoped invitation after offline discussion

### B0. Owner invitation setup
Owner chooses `Start request for client` in his workspace, enters a brief summary, select zero/many approved **published** services, optional sanitized evidence, desired client response. System makes `OwnerProposalDraft`, separate from existing approved contract/spec.
**Share:** 192+ bits random token, DB stores **hash only**, scope-bound to Owner workspace, expiring, one-time claim, revocable; no secrets or PII in URL or logs. Link not a login bypass.
**Security states:** `draft → invited → claimed → expired|revoked`. Before claim there is no implicit account, project or accepted price.

### B1. Client opens link
- Public landing shows only sanitized proposal summary after token validation, clear origin from owner, `Create account` / `Sign in`. Do not expose private files or user identity in previews.
- After verified registration, atomically claim token (one client only; idempotency); bind proposal to own customer account and load **editable** initial request draft.
- AI introduces `This is the owner's understanding; please correct anything inaccurate` and offers explicit `Accept fact`, `Edit`, `Don't know`, `Add requirement`.
- Then flow converges with Journey A1→A2. Claiming the invite **does not** accept owner assumptions or pricing.

## 5. Owner technical package and internal scope offer

Owner gets a **private** project analysis room:
- user story / traceable source requirement, assumptions, threat/privacy model, proposed Rails routes/controllers/models/jobs, SQL/schema changes, APIs/contracts, data migration, roles, integration docs, env access checklist without raw secrets, observability, tests (request/system/security/acceptance), deployment rollback/backups.
- Workload model: owned concurrent projects, available hours/day, planned holidays, timezone, fixed consultations, deadlines, risk contingency **private**, estimate range with explicit buffer rather than false precision.
- AI proposes `internal_hours_min/max`, `effort_by_phase`, `dependencies`, `risk`, `calendar_slots`, `budget_cap`, `scope_version`; rails checks conflicts and human approves.
- Approved client-facing non-legal `ProjectAgreementRevision` includes included/excluded scope, deliverables, milestones, acceptance criteria, bounded change-control and an *agreed price/date only if owner explicitly sets them*. Never show owner margin/buffer or other clients' schedules.

**Two-party version state machine:**  
`client_submitted → owner_review → owner_offered(vN) → client_changes_requested → owner_offered(vN+1) → client_accepted(vN) → owner_confirmed(vN) → active`. Exact revision digest + timestamp + authenticated actor stored on each acceptance. `Client viewed` ≠ `accepted`. Revisions immutable; editing produces new version. This is an in-app scope agreement, not legal signing.

## 6. Execution, calendars and notifications

Once the exact revision receives both approvals:
- Transactionally create `Project`, milestones/tasks and linked `ProjectCalendar` proposals. **Never** auto-book time from AI text; propose → check overlaps/working days/timezone → review/edit → confirm.
- Keep **consultation calendar** separate from project/task calendar; shared availability checks may consider both.
- One client may have N projects; each project has explicit client membership, own files, tasks, events, versions, AI conversations, messages and alerts.
- Each project screen surfaces `Current agreed revision`, status, next action, issues/risk, visible customer milestones, private owner workbench, notifications.
- Event-driven notifications only for committed transitions, with dedup keys (e.g. `project:revision:action`), recipient visibility, digest and delivery ledger. Do not create notifications from unapproved AI guesses.
- Client change request produces `ChangeProposal`; AI computes affected scope/dates/costs → owner approves new revision → client approves → recalibrate future tasks. Past completed evidence stays immutable.

## 7. UI / floating AI / screen-level AI action contract

| Surface | Entry/button | AI receives | UI result | Writes? |
|---|---|---|---|---|
| Public service card | `Explain this service` | published info only | concise popover/side sheet | None unless explicit opt-in |
| New client request | `Help choose`, `Suggest next`, `Explain option` | selection, answered question IDs | options + uncertainty, not chat wall | On client confirmation |
| Invite review | `Compare understanding` | sanitized owner seed + client corrections | suggested differences, attributable to owner/client | Client confirms draft |
| Client project room | Floating `Ask about my project` | **own** accepted revision, own history | explanation, citations, request more info | Client approves any change |
| Owner inbox | `Analyze request` | exact authorized request and versions | risks, unknowns, suggested spec | Owner applies to draft |
| Owner tech room | `Technical breakdown` | approved scope, owner private capability, schedule | routes/schema/APIs/tests/estimates with explicit caveats | Owner applies tasks |
| Calendars | `Plan time` | permitted events, timezone, scope | proposals/conflict warnings | Explicit owner confirmation only |
| Files | `Analyze selected` | exact approved files, explicit consent | extraction / test suggestions | Review before source update |

Floating AI dock is **context-aware navigation** to the same scoped engine, not a hidden parallel database or autonomous agent. On each open it shows active scope, actor/role, selected project and whether any file will be sent. Cross-project questions require explicit project switch. On a page, AI action components show specific inputs, provenance, cost/consent, preview and apply; they never submit a promise silently.

**Zero unnecessary page reloads:** Turbo Frames/Streams for supported forms and chat; Stimulus controls progressive loading, local file selection, draft warnings; Rails is always source of truth. Streaming/polling transport selected after evaluating host/worker limits. All controls usable with JS disabled (normal form POST fallback); reduced-motion preferences respected. Adaptive 320/390/768/1440.

## 8. Moderation and trust
- Deterministic rate limits, CSRF, content size constraints and abuse signals at entry. Avoid collecting user secrets.
- Rule-based warning for harassment/spam, safe deferral of abusive content for review; temporary throttling on repeated clear abuse, audit and appeal process.
- **Fraud suspicion cannot automatically cause an irreversible ban**: treat detection as a signal, review evidence, permit appeal. Critical verified abuse may require immediate temporary protection. Human-owned permanent ban workflow.
- Protected reporting and project data retention policies; never leak one client's information in another client's AI context.
- AI public browsing/knowledge connectors must have explicit feature gates, domain restrictions, max fetch size/time, citation capture, prompt-injection defensive parsing and user-approved cost.

## 9. Current source reconciliation and release gates

**Already implemented (do not recreate):**
- `User/UserSession` and verified client local pilot.
- `ProjectIntake`, `IntakeMessage`, `IntakeAnswer/Revision`, `IntakeSpecVersion`, initial milestones, owner inbox.
- `ServiceOffering/Version` with separate publication, owner profile, AI spend/quota.
- `OwnerAiConversation/Message` — owner only, not a cross-role project room; first live Grok response and title tested 2026-11-18.

**Not yet implemented and must not be claimed:** Guest public AI, service multi-select join, owner invitations, claim flow, client page-context AI, complete 12-section sourced spec, bilateral agreement states, project/task/notification event store, multi-project scoped AI memory, internet browsing, full moderation, production-safe media.

**Next vertical release slices (each: CI, manual user screenshot and separate Railway gate):**
1. C2.1d owner conversation UI & private AI attachments → exact-head CI + reload/owner proof + file ACL + desktop/mobile.
2. E1 client-owned request creation from zero / one / multiple published services (or no selection); persist immutable service references and draft answers.
3. E2 owner invitation → verified client claim → same request E1 builder.
4. E3 adaptive client intake & 12-section versioned spec (starting one Rails bugfix scenario with traceability).
5. E4 owner technical review/workload offer → non-legal bilateral acceptance.
6. E5 project tasks + dual calendars + real notifications and change requests.
7. E6 files/knowledge/moderation/integration and release hardening.

**Railway baseline (verified 2026-11-18):** production web commit `90d7a81`; new branch is >300 commits / 8 prior migrations ahead. Web has no persistent Active Storage volume, production has PG18 Postgres volume. Do not enable real customer data or deploy private media until durable storage and legal/privacy gates. Production per-deploy `db:migrate` requires tested restore/rollback and backup.
