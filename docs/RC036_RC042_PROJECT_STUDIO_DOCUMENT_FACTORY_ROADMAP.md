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

## RC-036 Stage 3 / Slice A — synthetic source metadata and tenant ACL (2026-11-10)
- Additive `ProjectSource` metadata-only registry: exact workspace/client/intake triple, verified owner membership and SHA256/format/size; no original filename, uploaded bytes, content, object key, or public download route.
- Composite PostgreSQL tenant FKs and CHECK constraints enforce `metadata_only` state and prevent forged cross-client associations; idempotency by project intake + digest + parser version.
- Service `Studio::ProjectSourceRegistry` accepts only a validated untrusted, non-persisted offline preview; `download!` always denies. Negative tests cover different clients in one workspace, foreign workspace, revoked membership, legacy intake, forged reports and direct SQL bypass.
- **Not the Stage-3 privacy gate**: encryption, durable private object store, AV scan/CDR/quarantine promotion, identity verification, consent, retention, authenticated delivery, HTTP/Turbo/job/export/AI denial matrix and recovery are still open. Do not upload real customer files or activate external AI.

## AI Settings / Per-project Feature Toggles — approved scope addition (RC-037 + RC-039)
- Workspace defaults with per-project overrides, owner-only configuration; strict precedence `system hard-deny > security/privacy/consent gate > workspace policy > project override > request choice`. A project toggle can only restrict an enforced policy, never turn off authentication, tenant ACL, audit, redaction or approvals.
- Central White Atlas **Project Controls** rail/panel in Project Hub: toggles for source ingestion formats, optional AI assistance, clarification, fact extraction, conflict analysis, document generators by type, board/timeline, reimport, exports, notifications and collaboration. Hide unavailable actions behind a clear reason and requirements gate. No SPA.
- Dedicated AI Settings: provider/model registry and selection per task; `off/offline/reviewed provider` modes; prompt/template/schema versions; allowed purposes/data classes; explicit external-AI consent; per-call/project/day/month token and USD caps; retry/timeout/cache controls; region/retention policy, model response validation, circuit breaker, audit and deterministic fallback.
- Default external AI OFF, billable calls disabled even if project switch is ON until owner-approved model, price and budget. Keep sensitive client content out of normal logs and provider prompts. Add negative tests for feature escalation, revoked consent, stale policy, cost limit and cross-project leakage. Distinguish `configured`, `enabled`, `available`, `approved`, `actually executed`.
- Settings UI and stored policy models belong to RC-037 foundation; toggles and Project Hub dashboard integration RC-039; export/notification-specific gates RC-040/041; E2E policy/a11y/perf RC-042. No effect on current production.

## RC-036 Stage 3 Slice B — scoped HTTP and non-redeemable invitations (2026-11-10)

- Owner-only HTTP lists source metadata with exact workspace/client/intake scope; every file-byte download (including owner's) returns 404 until private storage and scan are implemented.
- Owner-issued ProjectInvitation: HMAC recipient digest, SHA256 token digest, 48-hour expiry, owner-only list and revoke, single plaintext token returned only once with no-store. Tokens cannot be redeemed, and never grant client identity or access.
- PostgreSQL tenant FKs and hard state constraints; negative HTTP/service tests for guests, foreign owners, client/intake IDOR, revoked membership, forged active state and cross-client DB writes.
- No private object bucket, malware scanner, actual customer upload, client login or shared attachment links; all remain release gates. The decision to skip backups applies to this development iteration, not an assertion of production recoverability. Production untouched.
- Next: privately configured durable object storage in authorized nonproduction, quarantine+AV/CDR release gate and request-time ACL download streaming; then client identity verification and invitation redemption.

## RC-036 Stage 3 Slice C — synthetic-only private source quarantine prototype (2026-11-10)

- Separate `ProjectSourceBlob` quarantined object registry and composite tenant FKs; random private keys, 7-day expiry, no filename/text/token stored in SQL. Existing `ProjectSource` stays metadata-only, and does not independently grant file access.
- In **test** and explicitly enabled local **development**, synthetic MD/TXT/JSON uploads (<=256 KiB) are stored under a separate ActiveStorage DiskService root, never the Railway web filesystem. Production storage is hard-disabled; no S3 bucket or cloud persistence configured.
- `Studio::ClamAvScanner` implements real clamd INSTREAM over a local UNIX socket, but no production scanner is provisioned. Unless an attested clean verdict matches stored SHA256 and size, download is denied. In CI a clearly labeled synthetic scanner stub verifies the state machine, not malware detection itself.
- Owner-only source download proxy rechecks workspace, membership, client and project intake on each request. No public ActiveStorage controller/link and no client redemption. Tampered or missing objects, revocation, expiry, infected/failed/unscanned files fail closed.
- Negative HTTP/DB and scanner-gate tests use **only synthetic fixtures**. Do not claim the real private durable object store, AV deployment, malware detection effectiveness, data-at-rest encryption, file purge, real client consent or login is complete. Never enable real customer uploads without those gates and explicit release approval.
- Owner has skipped backups/restore for this development iteration. This does not certify recovery; production is untouched. Next: provision private durable object bucket in separate non-production environment, external scan integration/retention deletion, verified client identity and consent, manual owner UX/HTTP security QA.

## RC-036 Stage 3 Slice D — isolated S3 + real clamd integration (2026-11-10)

- Pinned official AWS S3 SDK gem. Production-disabled PrivateSourceStorage opt-in S3 backend with nonproduction-only config, no public ACL or direct download URLs. See [Slice D runbook](RC036_STAGE3_SLICE_D_S3_CLAMD_RUNBOOK.md).
- Owner-only synchronous /sources/:id/scan exists ONLY for synthetic test/local development, using ClamAvScanner UNIX INSTREAM.
- Bounded ProjectSourceRetention deletes expired object bytes and revokes metadata, retains source history. No production cleanup scheduler.
- Dedicated branch-only GitHub Actions spins up temporary maintained SILO S3-compatible storage plus genuine clamd with a **test-only EICAR signature**, then tests S3 upload/quarantine/scan/download, anonymous object denial, ACL/IDOR/revocation and expiry.
- **Not production-ready:** no deployed private durable bucket, live updated ClamAV signatures, worker/scheduler, monitoring, real client identity/consent or actual provider security acceptance. No production/billing changes. No backup work per owner decision.

## RC-036 Stage 3 Slice E — nonproduction mailbox-possession proof (2026-11-10)

- The user requested continuing with no separately approved paid cloud resources. No durable bucket or real production ClamAV was provisioned; Slice D already proved S3-compatible API + genuine clamd with a synthetic signature in CI.
- Added ProjectInvitationEmailProof (one per invitation), HMAC/SHA256 challenge digest, 10-minute expiry, five failed attempts, one-time confirmation, plus anonymous nonproduction-only JSON endpoints and test/local email delivery. No raw recipient email, token, or OTP is stored in the new proof table; generic initiation response avoids revealing known invites.
- Mailbox proof is **not** account authentication, not government identity/KYC, not a tenant membership, not consent, and **not** invitation acceptance. ProjectInvitation remains strictly pending/revoked and non-redeemable; workspace and all source/file HTTP routes remain owner-only.
- Production request routes return 404 regardless of supplied flags; no live email provider configured. Manual client login, verified recipient-account binding, password/session controls, consent, and per-action ACL matrices remain separate release gates.
- Negative HTTP tests: token-only/recipient mismatch, expired/revoked invite, exhausted attempts, replay/duplicates, revoked owner membership and forbidden access to source metadata after mailbox confirmation. Production untouched.

## RC-036 Stage 3 Slice F — invitation-bound client identity prototype (2026-11-11)

- New **separate** Studio::ClientAccount and Studio::ClientSession, not a second role on owner User; stored client mailbox is HMAC digest rather than plaintext, password bcrypt digest, DB-backed revocable 4-hour session in encrypted Rails session cookie. Production always denies client routes regardless of environment flags.
- Studio::ClientOnboarding requires both the previously verified and still unexpired mailbox challenge, an invitation matching the account's email HMAC, a strong password on registration, and explicit client agreement to a versioned `studio_review_v1` policy. Existing accounts authenticate separately before accepting a second invitation.
- Studio::ClientProjectGrant records each acceptance **exactly once** (unique invitation index, transaction-scoped row lock) and is bound by composite PostgreSQL tenant FKs to original workspace/client/intake/invitation. It is NOT a general workspace membership or file permission. Initial allowed surface: **read-only minimal project title/ID**. Source files, AI, owner notes, raw answers, document factory and all owner APIs remain inaccessible to client identities.
- Revocation of an owner-issued invitation also revokes the linked grant. Every allowed request rechecks grant, account status, original invitation revocation, workspace suspension and owner membership status. No grant is possible from a bearer token alone, unknown email, missing consent, stale proof or without login.
- Only test and explicitly opted-in local development routes are available. No public client signup/production email verification/KYC/full identity verification, real customer data or production deploy. Mailbox proof establishes **mailbox possession**, NOT legal identity/KYC. No paid S3 service or live ClamAV was provisioned.
- Release gates: external email provider, legal/UX review of consent, stronger account anti-abuse and recovery, MFA if required, browser+manual security review, permanent encrypted private bucket, live maintained AV with official signatures, retention worker and audit. RC-037 paid AI remains OFF until approved.

- Security hardening follow-up: OTP confirmation stores only the SHA256 invitation digest in that browser's encrypted Rails session; registration and acceptance additionally require a constant-time same-session proof check. Cross-browser reuse of a leaked invitation token, even after somebody else confirms the mailbox, is denied. Session claim is cleared on acceptance or session rotation. Separate negative HTTP test covers theft/replay across independent browser sessions.

## RC-036 Stage 3 Slice G — nonproduction infrastructure readiness (2026-11-11)

- Railway official S3 docs confirm: storage buckets are private, but server-side encryption, bucket lifecycle, versioning, locks not yet supported. Therefore **not accepted for customer files** under required privacy gates; no bucket created. See [Slice G infrastructure runbook](RC036_STAGE3_SLICE_G_INFRA_READINESS.md).
- Added read-only `Studio::NonproductionStorageAudit` for AWS-compatible private bucket encryption, explicit public access block/policy nonpublic, `q/` lifecycle <=8 days, reachable bucket. Unknown/unsupported API is fail-closed; outputs only checks, never secrets. This is a capability probe, not production certification.
- Added local-only official ClamAV/FreshClam Docker Compose, persistent signature volume, 127.0.0.1:3310; scanner now supports only local loopback TCP or existing UNIX socket, with timestamp freshness gate on TCP (96h) before INSTREAM. Timestamp is not authenticity proof; operational FreshClam evidence remains required. No remote/public TCP, production remains disabled.
- Cost gate: official ClamAV Docker notes ~4GB RAM; Railway RAM usage rate $10/GB-month implies ~$40 for 4GB continuously used before CPU/network/storage. Storage alone $0.015/GB-month is not the scanner budget. No paid service created. RC-037 remains gated.
