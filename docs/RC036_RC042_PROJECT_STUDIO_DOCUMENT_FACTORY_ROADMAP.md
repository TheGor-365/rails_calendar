# RC-036–RC-042 · Project Studio / Document Factory extension
**Status:** approved product direction from owner, 2026-11-10; **not a released feature**. Stacked Draft PR #36. Source of truth: existing RC-035B/RC-036 handoff and master RC-035–042 roadmap. This is an additive extension, not a claim that the features below already exist.

## Product outcome
One workspace supports a bidirectional, repeatable, source-traceable cycle:

\`owner conversation → original file(s)/URL/repo → controlled import → current project dossier → prefilled, invite-only client questionnaire → clarification / chat / decisions → human-approved brief / scope → generated document packs, full industrial roadmap, financial scenarios and slides → permissioned web review → versioned exports (MD/JSON/DOCX/PDF/PPTX etc.) → reimport changed documents → safe reconciliation, no overwrites\`.

Owner initiates with or without an existing customer; customer may enter through a verified invitation and continue an existing prefilled dossier or begin with a blank form. Every edit is a new event/revision with author, permission, source and timestamp. A share link is not equivalent to proof of client identity or permission to read all data.

## UX: Project Hub inspired by Trello, not a dense dashboard
White Atlas design tokens stay intact; Rails ERB + Turbo Frames/Streams + small Stimulus controllers; no SPA rewrite.

- Project header: title, state, progress, next recommended action; breadcrumbs / command menu.
- One narrow horizontal workflow rail: **Sources → Discovery → Brief → Specs → Roadmap → Delivery → Handoff**. An unread badge/issue icon only when actionable; no decorative badges.
- Main canvas: current task, not all documents. Side drawer contains source references, revision diff, owner/client comments. Header actions: Upload, Invite, Generate, Review, Export (permission-gated).
- Board view with movable cards and clear status buckets **Incoming / Need info / Ready for review / Approved / In progress / Done**, saved views (board/list/timeline), bulk actions gated by permission. Drag/drop never silently approves scope or finances; server verifies transition + expected version. Keyboard accessible Move menu and undo for non-approval changes.
- Dropzone supports click, drag/drop, multi-file and upload progress with Turbo/Stimulus; no hidden auto-submit. Upload returns a *preview* and detected data gaps first. An explicit confirm action records content.
- Every document is a compact card: type, version, audience, updated time, status, source coverage, missing evidence, last reviewer. Open as readable document with comments / version diff, not a giant scrolling chat.
- One central activity timeline for messages, answers, document versions, approvals, imports and exports. Separate unread/milestone markers.
- Project AI sidebar is contextual: **Ask a question**, **Clarify missing**, **Propose document**, **Compare versions**. Never auto-run the whole factory.
- Empty/error states: upload unsupported, scan pending, no budget, permission denied, expired invite, stale version, external change conflict.
- Mobile 320/390/430px, focus/keyboard, accessible alerts; design remains simple at a glance.

## Data model & trust contract
**Scope every object:** Workspace → Client → ProjectIntake → Project/Artifact. Historical owner-only synthetic records remain unassigned until a reviewed one-by-one mapping. Composite foreign keys protect client/workspace consistency in PostgreSQL. Every controller, Turbo Stream, background job, search, export and attachment proxy rechecks server-side ACL.

Planned domain:
- \`ProjectSource\`: source kind \`upload/url/github/message/form\`; version, content hash, MIME/signature, size, classification, author, virus/scan status, sensitivity, consent, storage key and retention.
- \`SourceSegment\`: immutable page/line/section or time-span reference, normalized text **encrypted at rest**, chunk hash, extraction version, provenance.
- \`ProjectFact\`: typed value, subject, status \`reported/verified/suggested/disputed/unknown/excluded\`, source refs, date, owner/client approval, expiry; no undocumented upgrades from reported to confirmed.
- \`Requirement\`: stable ID and acceptance, rationale, source segment(s), version, priority, dependency, risk, status, affected artifacts.
- \`Decision\`, \`ClarificationThread\`, \`ReviewComment\`, \`Approval\`, \`ActivityEvent\`: bidirectional exchanges and authoritative decisions.
- \`DocumentArtifact\`: type, locale, audience, title, status, parent, checksum, inputs fingerprint, template/model/prompt versions, approval policy.
- \`ArtifactRevision\`: immutable content + source manifest + diff link; copies do not become approved simply because content matched.
- \`GenerationRun\`: stage DAG, input set/revision, cost ceiling, provider/model, token counts, output validator, audit, idempotency and retry states.
- \`Invitation\`: scoped to client/project/role, single-use digest token, short expiry, verified recipient login, revoke, explicit allowed actions. Prepopulation is only from permitted summarized facts, never private owner's notes.
- \`ExportBundle\`: deterministic manifest with hashes, redaction policy, formats, audience and expiry; URLs generated by authenticated controller only.

Legal/privacy: no real client uploads or PII until storage encryption, key rotation, antivirus/quarantine, retention/deletion, proof of consent and cross-client ACL tests. No sharing direct public Active Storage signed-blob URL. Rails documentation warns blob controllers are public to anyone with link unless wrapped by authenticated controllers. OWASP recommends signature/type/extension/size checks, quarantine and antivirus, safe names, CSRF and ZIP bomb defense.

## Import / normalize / reconcile algorithm
1. Authenticate actor, authorize \`import\` on the exact tenant and intake; verify consent and purpose. Enforce quotas by workspace/user.
2. Quarantine file in **private durable object storage**, not the ephemeral Railway web filesystem; random object key; size and decompression caps; extension+MIME+magic checks; antivirus/CDR where appropriate; no HTML/JS execution; no render raw markdown HTML.
3. Parser registry: **MVP MD/TXT/JSON** (read-only UTF-8 + safe strict JSON), then **CSV/XLSX**, **PDF text**, **DOCX**, **PPTX**, image OCR only when explicitly needed/approved. URLs/repositories are separately allowlisted fetchers with SSRF protection, timeouts and robots/rights checks. Every parser is sandboxed with CPU/memory/file quotas.
4. Canonicalize headings, table cells, questions, acceptance checks, constraints, names of functions and source locations. Capture \`SourceSegment\` IDs and checksum; labels such as "urgent" in an uploaded document are *untrusted content*, never AI instructions.
5. Compare with existing dossier: \`new / corroborates / conflicts / supersedes / unknown\`. Never silently overwrite an accepted requirement or client answer. Show diff and ask for owner/client resolution.
6. Build prefilled quiz from approved or respondent-reported facts **with source and uncertainty tags**. Client sees "We prefilled this from your document; confirm/edit" and may mark "not sure".
7. Record every confirmation as a separate event and immutable fact revision. Trigger only dependent generators whose inputs changed.
8. No model call at steps that deterministic parsing / catalog rules can solve. AI receives the smallest authorized source chunks and typed facts, not every file, message and revision.

## Generation decision engine (deterministic DAG before any LLM)
\`Source Import → Normalized Dossier → Discovery gaps → Reviewed Brief → Requirements → Architecture → Roadmap/QA → Delivery Plan → Finance/Proposal → Presentation → Handoff Bundle\`.
Generator knows allowed input states, min evidence, owner/client approval, default format, sensitivity and required redaction. Output always has \`draft/suggested/needs-review/approved/superseded\`, never magical "final" from the model.

| Artifact | Gate / inputs | Output |
| --- | --- | --- |
| Discovery brief & interview | Source headings and respondent facts | 1-page summary, assumptions, open questions |
| PRD / BRD / SRS | Reviewed goals, personas, approved scope | Stable requirement IDs, boundaries, acceptance |
| UX maps / user stories | Confirmed scenarios and user roles | Flows, page map, wireframe description |
| Technical architecture | Confirmed stack/integrations/constraints | ADRs, component diagram, DB/ERD plan, API contracts |
| Security/privacy | Data classes, identities, risk and jurisdiction | Threat model, ACL, retention, compliance questions |
| QA/test plan | Requirement IDs and acceptance criteria | Traceability matrix, automated/manual test strategy |
| Industrial roadmap | Dependencies, estimates and priorities | Epics, features, tasks, milestone gates, critical path, risks, ownership, capacity, release plan |
| Budget/finance | User-confirmed currencies, rates, hours and costs | Scenario-based CAPEX/OPEX, TCO, cash-flow, ROI assumptions, confidence ranges; **no invented prices** |
| Commercial package | Human-approved deliverables, scope, price/date | Proposal, change orders, exclusions, acceptance contract draft |
| Pitch deck | Reviewed product/market/business content | Presentation outline then PPTX/PDF slides; no misleading metrics |
| Handoff/README | Approved revision + runnable evidence | ZIP manifest, MD/JSON, docs/code links, changelog, security redaction |

## RC roadmap expansion (preserving release IDs)
- **RC-036 Stage 2:** optional workspace/client binding for new intakes; old intake left unassigned, cross-tenant access service and tests; owner-only safe import *preview* (no persistent real client data); project/source metadata, source validation contract, invitation domain model without public route.
- **RC-036 Stage 3:** verified invitation/recipient identity, client role with exact policy matrix, private durable upload storage with authenticated download proxy, encryption, malware scan/quarantine, retention/deletion, audit/consent, idempotent import. Activate client interactions only after IDOR E2E.
- **RC-037:** offline-first AI dispatcher + source selection, retrieval ACL, typed prompt registry, structured output validation, per-run daily/project USD caps, anti prompt-injection tests, measured model comparison. First paid call only after explicit approval.
- **RC-038:** Source normalization/ambiguity resolution, project fact graph, requirement traceability, bidirectional Review/Approval, document revisions and diff; generate BRD/PRD/SRS and other core docs in dependency order.
- **RC-039:** Trello-inspired Project Hub, boards, cards, tags, assignments, timeline, commenting, Turbo/Stimulus drag/drop with authorized transitions, project calendar independent of consultation calendar, full roadmap (epics/deps/critical path).
- **RC-040:** Document Factory outputs, verified templates, Markdown/JSON/DOCX/PDF/PPTX bundles, finance scenarios, presentations, export manifests and integrity checks; reimport/diff and file→web→file roundtrip tests.
- **RC-041:** owner-initiated prefilled invites, customer-initiated intake, follow-up inbox, notifications and conversion measurement, multilingual public funnel only after eligibility/privacy.
- **RC-042:** full cross-client adversarial E2E, a11y, large-file/ZIP/timeouts, RAG poisoning, financial accuracy tests, prompt budget, backup+restore Postgres and files, signed release, RU/EN product walkthrough and portfolio proof.

## Quantitative acceptance metrics
- Zero unauthorized cross-client access attempts succeed across DB, HTTP, Turbo, storage, exported files, generated documents and AI retrieval.
- Import idempotency: identical source hash and parser version yields same preview; reimports create an explicit new revision only for changed content.
- Traceability: 100% of asserted requirements in generated specs link to source segment, respondent confirmation or labeled human-authored decision. Unknowns are never silently converted to fact.
- A document cannot be approved when required source evidence is absent or conflicted; every change to approved scope generates a review request.
- AI: baseline comparison across synthetic golden fixtures measures correctness, hallucination rate, missing clarifications, retrieval leaks, tokens/USD and latency. Cache keyed by tenant + source/revision + prompt/template/model version.
- UX: clear primary action, readable upload failure reason, no sideways scroll at 320/390/430px, keyboard-only import/review/board operations.
- Exports: exact approved artifact/source manifest reproducible; client cannot access owner-only or other clients' documents.
- Production: **no deploy** without backup+restore proof, exact SHA CI/Security and explicit release approval.

## Immediate implementation slice
Only owner-scoped synthetic/test data in Draft PR #36: add nullable workspace/client links for *new* intake, no backfill; implement deterministic UTF-8 MD/TXT/JSON preview + source fingerprint and artifact DAG planning in service layer; tests for size/binary/bad JSON, cross-tenant IDs, no AI/provider calls. No public upload endpoint and no document bytes stored before private storage/privacy gate.
