# ADR003 — AI-first commercial funnel: offerings, unread, qualification, approval, project and files

Date: 2026-11-15. Status: **proposed architecture / NOT implemented**. Context: owner-led Rails Calendar / White Atlas.
Based on code reviewed at `2701aa339857663a13b12bd03278f93e4d93e5aa` and user screenshots of RC054.3a.
No consent to release, no authorization for paid Grok, no claim that current demo request is production data.

## 0. What actually exists

- `ProjectIntake::TYPES` = `website / redesign / rails_bugfix / api_integration`; both client form and offline quiz rely on it. No service-offering model.
- `OwnerIntelligence::Catalog` captures six interview sections; `ProfessionalContextSnapshot` and `ProfessionalCapability` provide versioned, immutable owner-declared capabilities, all private and review-required. Owner must approve reclassification (direct/ai_assisted/evaluate_first/excluded); self-report is not proof.
- `ClientRequestsController#create` writes one `client` goal message and a static `assistant` acknowledgement. It DOES NOT run qualified AI dialogue.
- `Intake::Grok` exists for legacy owner synthetic demo questions and spec drafting, with gated API, spend ledger, idempotency digest and template fallback. Not yet context-bound to approved service versions. No paid call by default.
- `Admin::ProjectIntakesController` drafts, manually edits, version-approves and plans speculative milestones. `client_reviewed_at` means read receipt, NOT legal scope acceptance. No proposal/quote, jobs/projects or deliverable package.
- No persisted per-owner intake read receipts. An `interviewing` status is NOT an unread indicator. No built project-file model or Active Storage attachment tables; `config/storage.yml` is only a service configuration, and Railway local disk is not a durable private client storage strategy.
- `ProjectIntake` has an optional client owner but not yet an explicit assignment to a provider/workspace. A future multi-provider rollout requires tenant ownership on every sensitive object, enforced in SQL and authorization.

## 1. Invariants and boundaries

1. Separate **capability** (owner experience/preferences), **offering** (an explicitly approved service clients may request), **request** (client facts), **qualification** (proposed fit), **approved scope**, **commercial agreement**, **work project**, and **deliverables**.
2. AI is a drafting/analysis component, not a contracting authority. It may suggest categories, questions, estimates, specs, tests and artifacts. Owner must approve published wording, feasibility, price/schedule and sends. Hard no-go never softens through prompts.
3. Store evidence/provenance and model input snapshot version. No inferential statement becomes a customer-provided fact. Immutable approvals, explicit change requests and stale-version checks.
4. All client content is untrusted. Never execute markup or embedded instructions; redact PII/secrets before sending to a provider; send only after consent/policy; prevent cross-tenant access.
5. Offline deterministic path must work when AI budget=0, 429, timeout or disabled. No optimistic "AI completed" states; timeout with uncertain charge must not be automatically retried.
6. Existing `/client`, `/client/requests/:id`, `/project_intakes/:id`, calendar and approved v1 remain supported. Local pilot handles fictional data; paid production is a separate release.

## 2. End-to-end user journey (client and owner)

| Step | Client White Atlas UX | Owner White Atlas UX | Backend and gate |
|---|---|---|---|
| 0. Offer configuration | Only approved public services (or "Other / needs assessment") | `/workspace/practice` → `/workspace/services` draft and publish | Immutable `ServiceOfferingVersion`, bind approved `ProfessionalContextSnapshot`, explicit manual visibility/review flags |
| 1. New request | Three short cards: choose goal/service, context, synthetic/real consent appropriate to environment | Not yet shown as "in progress" until actually saved | `ProjectIntake` + immutable offering reference/snapshot; validate input, consent, idempotency on submit |
| 2. Inbox | Receipt with real "sent" status | Menu badge #unread, inbox "New" dot, sort and source labels | `OwnerIntakeReadState` / owner-specific last seen message marker; badge counts unread **requests**, not all interviewing requests |
| 3. Fit and triage | "Awaiting review" or one factual clarification; no automated promises | `Fit / Risk / Missing facts / Evidence / Recommended next question` suggestion panel | Deterministic hard-no checks first; optional paid Grok run gated by owner-approved snapshot, consent, cap and dedupe |
| 4. Clarifying interview | Step "Question n" + answer, attachments later; never repeat known answered facts | Owner may edit, replace, skip, or ask manually before AI-generated question is sent | Versioned `IntakeTurn`, actor, source, original model draft, human final, status pending/published; transactional audit |
| 5. Scope | Only owner-published spec revision vN and explicit unknowns/exclusions | AI/manual draft → editable sections → owner approval | Existing `IntakeSpecVersion`; preserve old revisions and origin. `client read`, `request changes`, `scope accepted` are distinct operations |
| 6. Quote | Only approved offer/terms, no fake availability | Edit terms/currency/price/taxes/schedule, owner approval | New `ProposalVersion`; separate verified payment feasibility gate; no automatic legal acceptance |
| 7. Project | Accepted scope/proposal, work timeline and progress | Workspace with tasks, acceptance criteria, calendar allocation | `Project` anchored to immutable scope+proposal; `ProjectTask`, versioned work events. Calendar is projection, not canonical storage |
| 8. Package | Downloads only explicitly shared final artifacts | Generate, inspect, version, approve and publish individual files | `ProjectArtifact` plus immutable `ProjectFileVersion` using private object storage; signed/authorized downloads; audit history |
| 9. Closure | Read receipt/acceptance only after explicit customer action | Final verification, deliverable handoff, factual payment status | Separate delivery acceptance, invoice and verified availability of funds; no automatic "paid" flag |

**Each screen has one primary next action.** AI suggestions appear in a side rail with `Suggested` label, source, freshness, cost and Confirm/Edit/Discard. A `Next` button is enabled only when server truth allows the transition.

## 3. Service catalog decision (fixing the current four-category dropdown)

Do not put raw competencies or every AI-suggested technology directly into public `project_type`. That would expose private owner facts and implicitly promise unsupported work.

- `ServiceOffering`: stable owner/workspace-scoped service key, ordering, internal lifecycle.
- `ServiceOfferingVersion`: title/description/category, `delivery_mode` (direct/conditional/evaluate_first), scope boundaries, must-review flag, requirements prompt, optional public status, `professional_context_snapshot_id`, immutable digest and owner approval timestamp.
- Client selector renders ONLY approved, visible offering versions, each marked "Standard" or "Subject to feasibility"; excluded work is never advertised. "Other / describe the task" goes to manual review, not automated rejection.
- On submission store `offering_version_id` (or null "other"), normalized category and snapshot version so future owner changes do not silently rewrite historical requests.
- Map old four `ProjectIntake::TYPES` to legacy grouping for backward compatibility, never reinterpret old rows. Add `offering_version_id` and migrations in a separate audited PR, after local DB backup and no production DB actions.
- **Owner acceptance needed** for capabilities v2 and each published offering. React/Vue/Python remain conditional until owner verified classification; no independent invention by AI.

## 4. Unread badge semantics and event contract

- `OwnerIntakeReadState(owner_user_id, project_intake_id, last_seen_client_message_id, first_seen_at, last_seen_at)` unique pair plus scoped foreign keys (proposed name).
- Unread if a client-associated intake has no receipt for this owner OR a client-authored message newer than its last seen message. Count distinct **intakes**, not individual messages, so one newly opened request increments menu by exactly 1. New draft/spec stages do not create unread by themselves.
- Mark seen only after authorized owner opens actual request details and the displayed client message marker is known. Merely loading inbox does not clear badge. Do not count assistant template acknowledgements. Multiple tabs and concurrent client messages must not erase unread; update max marker atomically.
- Show `●` on unread inbox rows and one compact count `1` on owner menu; no badge if count=0. The mobile view must expose the count accessibly. Use DB query/transaction; optionally Turbo Stream later, not as a substitute for persistent truth.
- Legacy administrator cookie and owner user session are different principals; explicit owner-authenticated read receipt is required for this first single-owner version. Full multi-tenant assignment is a separate authorization step.
- Acceptance: two unread requests count 2, opening one reduces to 1, new client reply makes it unread again, owner switching/foreign client cannot mark or inspect another's records, refresh and new browser preserve count.

## 5. AI qualification/interview orchestrator

`Intake::Workflow` (pure state transition), `Intake::Eligibility` (hard policy), `Intake::QuestionPlanner` (deterministic first), `Intake::AiTriage` (optional), `Intake::SpecDraft` (existing version engine adapter), `Intake::Publication` (owner ACL/version gate).

- Inputs: approved service snapshot + restricted shareable fields, project goal, prior client messages, explicitly verified attachments, prior derived facts; all with provenance.
- Output strict JSON: `fit` enum [fit, conditional, review_required, no_go], `fit_reasons`, `known_facts`, `open_questions`, `risk_flags`, `recommended_question`, `confidence`, `needs_owner_review`, `source_snapshot_digest`, `cost_ledger_ref`.
- Check both the model schema and server-side business policy. A model cannot change owner hard-no, pricing, versions or read flags.
- Model run idempotency: request digest of operation + approved snapshot + input version, persisted task/ledger; bounded tokens and budget, no duplicate payment on retries; uncertain charge awaits reconciliation.
- Question planner suppresses semantically duplicate questions and asks one actionable next question; owner may approve/edit/skip and the client gets only published question. The system tracks who asked what, when, with which model or manual draft.
- Offline fallback: predefined category-specific questions plus manual owner actions; no fabricated AI score, completed diagnostics or made-up timelines.
- A no-go is an owner-facing recommendation/hold, not automatic rejection with legally consequential claims.

## 6. Files, downloads, provenance and location

**Current application does not provide a project folder or download page.** Future logical hierarchy (virtual, database-backed; not a public path under `public/`):

```text
Workspace
└── Projects / PROJ-00042
    ├── Overview + approved scope
    ├── Tasks + calendar
    ├── Files
    │   ├── 01-request/        (client source, private)
    │   ├── 02-discovery/      (questionnaires, redacted logs, evidence)
    │   ├── 03-specification/  (spec-v01.md/pdf, approvals)
    │   ├── 04-delivery/       (code diff, test report, screenshots)
    │   └── 05-handoff/        (approved export package)
    └── Decisions + history
```

- Tables: `ProjectFile` logical metadata (project, folder, uploader, allowed audience, classification, status), `ProjectFileVersion` immutable attachment reference, checksum (SHA-256), content type, byte count, approval, timestamps; `ProjectArtifact` references generated files and source scope revision.
- Use Active Storage **after installing its migrations**. Dev can use existing local Disk service for fictional files; production must choose a persistent **private** object store with tested backup/recovery, not Railway ephemeral `storage/`. Reject executable/path-traversal content, enforce extension/MIME/size limits, malware scan/retention/access checks.
- Owner file view: table "Name / Type / Source / vN / Visibility / Updated / Preview / Download"; preview text/images/PDF only after ACL. Client file view shows only individually published files. Download via authorized controller + short-lived private blob URL; no guessing object key.
- Export package generated on explicit owner action from approved spec and artifacts: `scope-vN.pdf`, `proposal-vN.pdf` only if approved, `implementation-plan.md`, `acceptance-checklist.md`, `handoff.zip`; do not fabricate implementation, tests or payment confirmation. Each generated document carries source revision and state.
- Do not include ID/KYC, API keys, raw client secrets, billing credentials. Separate upload/publication/download audit records.

## 7. UI component map: keep White Atlas

- Shared atoms: existing `rc-action`, `rc-status-pill`, `rc-record`, `surface-panel`, `wa-spec-section`, `rc-select`, `wa-autogrow`.
- New scoped elements: `wa-intake-progress` (Request / Triage / Questions / Scope / Quote / Project); `wa-unread-count` (single owner menu badge); `wa-source-pill` (client, AI draft, human-approved); `wa-approval-gate` (draft/edit/publish buttons); `wa-activity` (real events); `wa-project-file-row` and `wa-file-preview`.
- Screens: `/client`; `/client/requests/new` (offering selector + structured brief); `/client/requests/:id` (published questions/spec/status); `/admin/project_intakes` (owner inbox with count/dots); `/project_intakes/:id` (owner workflow & review); `/admin/project_intakes/:id/edit_spec` (versioned manual editor); future `/workspace/services` (owner offering catalog), `/workspace/projects/:id` and `/workspace/projects/:id/files` (project workspace).
- No global redesign: desktop wide content, existing white cards/teal accent, grouped form sections, mobile dock; 1440/768/430/390/320 and keyboard/ARIA. Avoid horizontally clipped file tables at 320; use stacked rows.

## 8. Suggested incremental PR order and test gates

1. **RC054.3b (current)**: apply existing auto-grow to manual owner forms and repair spec form scope; no DB. Exact SHA CI and owner screenshot gate.
2. **RC054.4a**: owner intake interview readable, source tags, manual question/spec controls; no AI or DB.
3. **RC055.0**: actual per-owner inbox read receipts and unread badge (new table and migration). CI + local DB backup + local migration validation + Chrome, no Railway.
4. **RC055.1**: owner confirms capability corrections v2; implement versioned `ServiceOffering` draft/edit/approve. Tests policy/provenance. No automatic publishing.
5. **RC055.2**: client dropdown binds approved offerings only with safe "Other" path; old type/category map retained. Cross-account and version tests.
6. **RC056.0**: narrow AI triage ADR/API contract, redaction/consent/ledger; deterministic qualification before any paid calls.
7. **RC056.1/2**: versioned client/owner questions, optional paid model-generated suggestions behind confirmation and cap; full multi-tab/conflict/429/timeout tests.
8. **RC057**: immutable spec revisions, client change requests, separate read and scope approvals, owner-approved proposal.
9. **RC058**: project/task/milestone model, file/version/access layer, preview and signed downloads; generated handoff package only after explicit approval.
10. **RC059**: staging restore of real production backup, migration inventory, tested rollback, legal/email/payment controls, user release approval; only then production.

Each PR: source audit, model/ACL tests, Chrome E2E, security, exact commit SHA, local browser acceptance, Draft until approved. Never silently migrate/merge/deploy.
