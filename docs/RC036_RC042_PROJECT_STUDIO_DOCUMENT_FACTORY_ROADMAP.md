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

## RC-036 Stage 3 Slice H — bounded PostgreSQL scan queue + race-safe retention (2026-11-11)

- Added one-task-per-synthetic-blob \`Studio::SourceScanTask\`, composite tenant FK, unique blob index, terminal audit states, retry schedule (5 / 30 minutes), three-attempt terminal exhaust, \`FOR UPDATE SKIP LOCKED\` for competing local workers. No paid queue service/Redis/scheduler.
- Owner-only \`POST .../sources/:id/queue_scan\` merely enqueues synthetic staged bytes. Local developer must explicitly run \`bin/rc036-studio-scan-runner\` with \`RC_STUDIO_LOCAL_SCAN_RUNNER=true\`. Rails production rejects both. Manual runner uses owner privilege and is not safe to expose on untrusted hosts.
- Scan and physical expiry cleanup now lock the same quarantine blob row to prevent in-flight scans from restoring clean state after retention deletion; membership and expiry are rechecked after scan. No automatic physical cleanup or orphan reconciliation yet.
- Tests cover clean/infected, failed/retry/exhaust, expiry and physical deletion, wrong tenant/client, revoked owner, fake scanner and production-disabled routes. Existing real S3 + ClamAV CI remains synthetic-EICAR only.
- Remaining real infrastructure, spend, official FreshClam update proof, worker/scheduler/monitoring and identity/consent signoff release gates unchanged. See [Slice H Runbook](RC036_STAGE3_SLICE_H_SCAN_QUEUE_AND_RETENTION.md).

## RC-036 Stage 3 Slice I — operations audit and orphan-candidate detection (2026-11-11)

- Owner-only read-only Studio::SourceOperationalAudit reports due/overdue queue, oldest due task, exhausted tasks, failed scans, expired-not-revoked, and clamd VERSION timestamp + PING health. Verified official AV signature provenance remains FALSE.
- PrivateSourceStorage#exists? plus retention post-delete HEAD verification: failure to verify absence does not mark a blob revoked; no false physical deletion receipt.
- Owner-only read-only Studio::SourceInventoryAudit: bounded S3 q/ listing (up to 100) and sampled scoped HEAD; global tenant lookup protects other workspace keys from orphan misclassification; minimum 2-hour grace for review candidate, no automatic removal and no keys in output.
- Manual local-only bin/rc036-studio-operations-audit with synthetic dev opt-in, no scheduled alerts or paid services. Negative tests cover stale ClamAV, false delete acknowledgment, partial listing, foreign tenant and provider failures.
- Further steps require explicit paid-provider/budget choice, verified maintained official ClamAV, durable protected storage, scheduler and comprehensive reconciliation, consent/E2E security acceptance. See Slice I Runbook: RC036_STAGE3_SLICE_I_OPERATIONS_INVENTORY.md.


## RC-036 Stage 3 Slice J — durable local run ledger + paginated reconciliation (2026-11-11)

- Added \`studio_maintenance_runs\` (one workspace/kind/time slot, PostgreSQL unique constraint), immutable terminal outcomes, generic error code and allowlisted aggregate JSON result. \`Studio::SourceMaintenanceScheduler\` is a **manually called** local tick, NOT running cron/worker: interval slots health/scan=5m, retention=1h, inventory=24h. DB workspace lock enforces a single claim; a crashed \`running\` row blocks newer slots until operator reconciliation, rather than automatically duplicating side effects. No silent retries.
- Default local tick chooses health, with explicit kind option. For retention, extra \`RC_STUDIO_ALLOW_LOCAL_PURGE=true\` and Rails development are required, never enabled in production; **no orphan auto-deletion at all**.
- Added \`Studio::SourceInventoryReconciliation\`: paginates S3 \`q/\` with continuation-token uniqueness/validation, page bound 100, at most 25 pages and 2500 workspace metadata HEAD checks. All S3 keys are joined against global DB metadata in bounded page batches to distinguish other workspaces; orphan candidates only for manual review after 2h. Return \`list_complete\`, \`db_complete\`, \`reconciliation_complete\`, \`snapshot_consistent=false\`, and no keys. If any budget is exhausted, returns incomplete instead of claiming full coverage. No S3 writes, delete, PII exposure, or production access.
- New CLI \`bin/rc036-maintenance-tick\`, development-only with explicit synthetic env. No scheduler deployment, no paid infra, no verified FreshClam official signatures, no real S3. [Slice J runbook](RC036_STAGE3_SLICE_J_MAINTENANCE_DESIGN.md). Full paginated snapshots are **not transactionally consistent** under simultaneous uploads; no automatic deletion permissions.
- Release gates remain provider/budget, encrypted permanent S3, official updated FreshClam, monitored production-grade worker/alerts, legal consent, safe recovery and approved E2E. RC-037 paid AI OFF.

## RC-036 Stage 3 Slice K — zero-paid local onboarding, operator recovery and resumable S3 (2026-11-11)

- Implemented Studio::OperatorRecovery: owner-attested closure of an abandoned (>30min) maintenance run with exact run-specific confirmation, operation-specific review reason and immutable Studio::OperatorReview receipt (unique per run, composite tenant FK). The run is marked failed, NEVER replayed. Separate local opt-in; no automated salvage or orphan deletion.
- Implemented Studio::InventoryCheckpoint and Studio::SourceInventoryResume: one active scope per workspace; encrypted/authenticated S3 pagination cursor, HMAC bucket binding and cursor hashes, fixed aggregate counters, one page or 20 DB HEAD checks per manual step; expires at 24h. Continuation works beyond 25 S3 pages/2500 DB records without losing progress; transient failures do not advance. Not an atomic snapshot or deletion permission.
- Added free, optional localhost S3-compatible SILO Docker Compose using existing CI-pinned image and private shell-provided synthetic credentials; explicitly opted-in HTTP only on development loopback. Disk storage remains the default no-S3 local path. Nothing deployed or purchased on Railway.
- Added local owner CLI bin/rc036-review-abandoned and bin/rc036-inventory-resume; no cron, paid background daemon or production access. Negative tests include wrong tenant, replay, tampered cursor, expired checkpoint and denied public HTTP.
- Read [Slice K local runbook](RC036_STAGE3_SLICE_K_LOCAL_RECOVERY_AND_CHECKPOINTS.md). RC-036 and RC-037 still blocked for real data/production pending separate privacy, identity, official AV signatures and explicit release approvals.


## RC-036 Stage 3 Slice L — independent synthetic local smoke (2026-11-11)
- Added `bin/rc036-local-smoke`, a nonproduction-only command that rejects remote/production database URLs, forces the dedicated `ruby_calendar_test` database and disk test backend, and runs a Rails HTTP/queue/retention integration suite. Failure exits nonzero; summary JSON discloses no real source bytes, keys or identities.
- New `test/integration/rc036_local_smoke_test.rb` checks a fictional MD/TXT/JSON upload → quarantine → queued PostgreSQL task → **FAKE TEST-ONLY** clean/infected verdict → request-time owner/tenant/intake ACL → expiry/physical retention → sanitized operational health. This does **not** grant any development blob a fake clean verdict.
- Optional existing disposable S3+genuine clamd EICAR CI remains separate; it is not official FreshClam malware-coverage evidence. No customer files, external AI/paid resource, merge or Railway production changes.
- Runbook: [Slice L local synthetic smoke](RC036_STAGE3_SLICE_L_LOCAL_SYNTHETIC_SMOKE.md). **CI/owner machine acceptance pending new exact HEAD; do not infer PASS from source code alone.**


## RC-036 Stage 3 Slice M — operator-only read-only status (2026-11-11)
- Added `Studio::SourceOperatorDashboard` to the existing manual local audit CLI: tenant-scoped queue/ClamAV/retention plus running/abandoned maintenance and incomplete inventory checkpoint counts. Zero automatic retry, recovery, deletion or S3 cursor advancement; no private IDs/keys/cursors.
- New security tests; standalone Slice L smoke executable now runs as a distinct Rails CI step. [Slice M runbook](RC036_STAGE3_SLICE_M_READ_ONLY_OPERATOR_STATUS.md). **Exact-HEAD CI/owner-machine validation pending.**


## RC-036 Stage 3 Slice N — preview hard-deny and untrusted HTML regression (2026-11-11)
- Found that preexisting owner preview could parse unscanned bytes in production despite synthetic-only policy. Patched `Studio::SourcePreviewsController` to require nonproduction test/explicit synthetic development, return 404 in production even for owner, and emit no-store/nosniff/no-referrer on early denied responses.
- Negative HTTP tests assert production 404 and safe escaping for raw Markdown HTML/JS with no persisted blob. [Stage N security boundary](RC036_STAGE3_SLICE_N_SECURITY_GATES.md). Other security/manual/legal/production gates remain explicitly pending until independent proof.


## RC-037 Slice A — scoped offline AI policy foundation (2026-11-11)
- Stacked Draft PR on RC-036: synthetic-only `studio_ai_policies` with project override, workspace hard-deny and PG composite tenant FK; `Studio::OfflineAiDispatcher` returns unapproved static offline proposal with zero external provider calls and zero billing. Project cannot escalate workspace restrictions; reviewed provider stays unavailable.
- Test suite for foreign/revoked owner, invalid classes and purposes, duplicate defaults and forged tenant SQL. [Slice A runbook](RC037_SLICE_A_OFFLINE_AI_POLICY.md). Full RC-037 dispatch/structured outputs/budget enforcement and UI remain future work.


## RC-037 Slice B — White Atlas offline AI Settings (2026-11-11)
- Added local/test-only owner-scoped Project Controls UI (two forms: workspace default and restrictive project override), GET/PATCH routes with production 404 and no-store headers, allowlisted offline purposes. No provider, consent or spending mass assignment, no auto-execution. Existing source preview has a navigational link.
- New HTTP tests verify form settings, hostile parameters, tenant IDOR, revoked owner, hard production-deny, zero-dollar dispatcher. [Slice B runbook](RC037_SLICE_B_OFFLINE_SETTINGS_UI.md). Actual visual/a11y acceptance on owner device pending.


## RC-037 Slice C — typed offline output contract (2026-11-11)
- Added immutable `Studio::OfflineTemplateRegistry` and strict `Studio::OfflineOutputContract`; dispatcher now validates all locally generated responses. Must remain synthetic/unverified/offline with zero network calls, billing or auto-approval. Reject unknown keys, injected provider output, unreviewed templates and faked provenance. No external model was invoked.
- [Slice C runbook](RC037_SLICE_C_OFFLINE_OUTPUT_CONTRACT.md). This is deterministic template validation, **not** a complete approved paid-model response pipeline.


## RC-037 Slice D — explicit source selection without private retrieval (2026-11-11)
- Added `Studio::OfflineSourceSelector`: owner scoped, <=10 explicit unique integer IDs, matching workspace+client+intake and metadata_only state, denied foreign/missing/duplicate/revoked. Offline dispatcher now counts only selected synthetic source metadata. No body/URL/object key is read or supplied to a provider.
- [Slice D runbook](RC037_SLICE_D_SOURCE_SELECTION.md); not RAG/content retrieval or client-data authorization. Encrypted durable storage, consent and approved provider policy remain unimplemented.

## RC-037 Slice E / phase 1 — append-only policy audit (2026-11-11)
- Added model-level immutable `Studio::AiPolicyRevision` rows with sequential HMAC-linked versions and a tenant-composite policy FK, scoped intake FK, actor attribution for owner UI, and explicit `internal_unattributed` marker for model writes without an actor. No email, prompts or source bytes in snapshots.
- `Studio::AiPolicy` now appends policy revisions transactionally for meaningful create/change; unchanged saves are not audited as changes. Direct SQL and DB administrators can bypass Rails callbacks, so independent backup/role hardening remain mandatory; do not claim this is tamper-proof storage.

## RC-037 Slice E / phase 2 — zero-paid AI admission + golden tests (2026-11-11)
- `Studio::AiBudgetAdmission` guards owner/tenant/purpose/data-class/production status and permits only `offline_template` with **zero estimated tokens and USD**. Persisted positive spending ceilings or external consent cannot permit a billable provider. Dispatcher calls gate before source selection. No API integration, token or budget reservation with real providers.
- Added independent static golden YAML expected outputs for 3 purposes and adversarial synthetic intake prompt injection fixture. [Slice E runbook](RC037_SLICE_E_AUDIT_BUDGET_GOLDEN.md); nonprod only and no customer/production claims.

## RC-037 Slice E — read-only audit history on existing settings screen (2026-11-11)
- Reused the existing owner-only project AI settings view to show the last 15 safe, scoped policy revision summaries (action, mode, event time, attribution) with no raw HMAC digests, email or source text; verified by HTTP tests. Does not change the zero-cost gate or production-deny boundary.


## RC-037 Slice F — fail-closed audit verification at request-time admission (2026-11-11)
- Hardened `Studio::AiBudgetAdmission`: verify HMAC-linked revision history and latest persisted snapshot of both workspace and project AI policies before any synthetic offline response. Direct SQL tampering, missing chain, changed scope and forged revision digest deny execution with no implicit repair. This is not independent WORM audit or permission for external billable AI.
- Negative service/dispatcher tests demonstrate bypass denial. [Slice F runbook](RC037_SLICE_F_POLICY_INTEGRITY_ADMISSION.md). Exact HEAD CI evidence recorded separately.


## RC-037 Slice G — explicit owner-only synthetic offline proposal (2026-11-11)
- Added POST `offline_proposal` on the existing AI Settings screen, after exact owner/tenant/intake ACL and synthetic-only production hard deny. UI selects only bounded per-intake `metadata_only` source IDs; controller strictly validates IDs and executes existing audited zero-budget gate + safe deterministic output. Displays unapproved text without storage, raw bytes, API calls, spending or auto-approval.
- HTTP negative tests for foreign/duplicate/oversized selection, owner revocation, production 404, forged provider/cost fields and audit SQL bypass. [Slice G runbook](RC037_SLICE_G_OFFLINE_PROPOSAL_UI.md). Human mobile/browser acceptance pending.


## RC-037 Slice H — immutable synthetic offline run ledger and owner review (2026-11-11)
- Added two PostgreSQL tenant-scoped append-only entities: versioned `Studio::OfflineRun` (limit 25/intake, project row lock, unique version) and signed one-per-run `Studio::OfflineRunReview` with `reviewed_synthetic` / `discarded_synthetic` decisions. Strictly fixed synthetic output contract, input metadata SHA256, HMAC integrity verification and composite workspace/client/intake foreign keys. No customer data, real provider, billable tokens, approvals or auto-execution.
- Added separate owner-only POST to record the existing ephemeral Slice G preview, and POST for an explicit review decision. Settings page displays last 10 verified synthetic versions; tampered data is hidden and cannot be reviewed. Synthetic-only production 404 unchanged. [Slice H runbook](RC037_SLICE_H_OFFLINE_RUN_LEDGER.md). Manual browser and full production readiness are NOT established by automated tests.


## RC-037 security and mobile acceptance (2026-11-11)
- Added targeted Selenium owner path at 320/390/430px, with no horizontal overflow, preview→versioned run→synthetic-only review, denied-policy and corrupted-signature checks; updated fixed-template `<pre>` wrapping for narrow screens.
- Added `bin/rc037-local-acceptance` (localhost `ruby_calendar_test` only, reject production/remote and unknown args) with `--check-only` and negative guard tests. It runs synthetic Rails and Chrome system tests; does not certify owner's actual Linux Mint run until user executes it.
- [RC-037 release gates/owner acceptance runbook](RC037_OWNER_ACCEPTANCE_RELEASE_GATES_2026-11-11.md) records infrastructure blockers and evidence requirements, including official antivirus signatures, encrypted durable store, DB+blob backup AND restore, legal consent and separate deploy approval. **Production blocked.**

## RC-037 — owner Linux Mint automated acceptance (2026-11-11)
- Owner's actual isolated localhost `ruby_calendar_test` run on Linux Mint: **PASS** with Ruby 3.4.12 and Bundler 2.6.9; targeted Rails **31 runs / 438 assertions**, local Chrome/Selenium **25 runs / 474 assertions** at CSS viewport **320/390/430px**, zero failures/errors/skips. See PR #37 checkpoint. Local generated `db/schema.rb` remained modified in owner's checkout and must not be reset or included in unrelated commits without examination.
- This validates isolated scripted checks, **not manual visual/keyboard acceptance**, genuine malware signature provenance, encrypted durable storage, client identity/consent or backup plus restore. Production and real-client release gates remain blocked.

## RC-038 Slice A — synthetic-only source normalization and fact provenance (2026-11-11)
- New stacked Draft PR #38 based on unmerged PR #37. In-memory `Studio::SyntheticSourceNormalizer` requires explicit synthetic opt-in, active owner+exact tenant/client/intake/source metadata match and correct SHA256/format/size. Production and quarantined bytes are hard denied; **no HTTP, DB migrations, stored source text or paid AI**.
- Deterministic bounded MD/TXT lines/JSON pointer segments with cryptographic text/source references; unverified `reported`/`unknown` candidate facts each linked to one emitted segment. Fenced code does not become a requirement, duplicate JSON keys are rejected, truncated/omitted evidence signals `partial` coverage. No client approval, verified facts, invoices or documents can be inferred.
- Isolated tests cover determinism, cross-tenant IDOR, revoked owner, stale hash, ambiguous input and no content persistence. [RC-038 Slice A runbook](RC038_SLICE_A_SYNTHETIC_SOURCE_GRAPH.md). Exact-head CI/Security results in PR #38 checkpoints, not presumed from file creation.
- Next: Slice B in-memory conflict/reconciliation preview, then human-review rules and persistent encrypted segments only after independent privacy/consent/storage gates.

## RC-038 Slice B — synthetic reconciliation preview (2026-11-11)

An additional in-memory service compares two already validated synthetic source graphs for one exact authorized workspace/client/intake. Candidate outcomes \`new/corroborates/conflicts/unknown\` and an explicit zero automatic supersede count; all require human review. Partial source coverage prevents claiming unobserved claims are absent; null values remain unknown. No persistent source text, approval, HTTP endpoint, AI call or production exposure. See [Slice B runbook](RC038_SLICE_B_SYNTHETIC_RECONCILIATION.md). Stage C can introduce owner reviewed decision previews and immutable storage architecture without weakening current production gates.

## RC-038 Slice C — synthetic-only owner conflict triage (2026-11-11)

A separate append-only metadata-only \`Studio::SyntheticReviewDecision\` stores owner triage after **recomputing both source graphs** with source SHA/ACL/quarantine checks, verifying exact comparison digest and hashed candidate ID, and demanding typed confirmation. Allowed decisions: \`needs_information\`, \`retain_for_review\` (only \`new\`/\`corroborates\` candidates), \`exclude_from_draft\`. Never creates \`ClientFact\`, approved scope, client consent or deliverable. One decision per source-pair revision and incoming candidate; no silent overwrite, exact retry idempotent, explicit review of changed source after revision. PostgreSQL composite tenant FKs cover both sources, intake/client/workspace, and model prevents update/delete. No raw bytes, filenames, freeform reviewer text or AI provider calls persisted. Only test/opted-in development; no production HTTP routes or client data. See [Slice C runbook](RC038_SLICE_C_SYNTHETIC_REVIEW_TRIAGE.md). Future: reviewed source segments/facts and document revisions only behind real privacy/consent gates.


## RC-038 Slice D — read-only synthetic review readiness (2026-11-11)
- Nonproduction-only \`Studio::SyntheticReviewReadiness\` recomputes source reconciliation and validates immutable owner triage metadata. A strictly internal \`eligible_for_unapproved_synthetic_outline_review\` flag is true only for fully triaged, complete, nonconflicting synthetic evidence with at least one retained candidate. It is **never** authorization to generate a document, approve scope or treat a client as confirmed. No source text is persisted, no routes or paid API. [Slice D runbook](RC038_SLICE_D_SYNTHETIC_REVIEW_READINESS.md).

## RC-038 Slice E — synthetic requirement trace preview (2026-11-11)
- Read-only \`Studio::SyntheticRequirementTracePreview\` composes validated in-memory comparison with existing owner triage, returning deterministic opaque trace IDs, source/segment/locator and reviewer receipt for strictly \`retain_for_review\` candidates in \`new/corroborates\` state. All requirement and client approvals remain **false**, no generated documents, persisted text or actual customer data. [Slice E runbook](RC038_SLICE_E_SYNTHETIC_REQUIREMENT_TRACE_PREVIEW.md).
- Exact-HEAD CI/Security and owner-machine tests required for Slice E acceptance. Future persistent fact graph, artifact revisions and actual document generation remain blocked by storage, AV, consent, backup/restore and manual release gates.


## RC-038 Slice F — synthetic requirement-revision delta, no document persistence (2026-11-12)

- Added in-memory \`Studio::SyntheticRequirementRevisionDiff\`: compares two independently owner-triaged, exact-source validated fictional candidate snapshots for the same workspace/client/intake. Uses bounded source locator + type only as a temporary coordinate and compares localized value hashes internally, without exporting source content or hashes.
- Classifications \`unchanged_unverified / changed_unverified / newly_retained_unverified / no_longer_retained_unverified\`; the latter is NOT proof of removed client scope, and changed/moved coordinates never auto-supersede or auto-delete. If either source comparison has partial coverage or unresolved/review-pending candidates, the diff is blocked.
- No persistent documents, revision approvals, HTTP, exports, cloud storage, paid AI or production features. All real-source, identity, encryption, maintained AV, consent, backup+restore and release gates remain open. See [Slice F runbook](RC038_SLICE_F_SYNTHETIC_REQUIREMENT_REVISION_DIFF.md). **Exact-HEAD CI and owner local acceptance required.**


## RC-038 Slice G — fictional document revision impact gate (2026-11-12)
- \`Studio::SyntheticDocumentRevisionImpact\` composes Slice F's exact-source checked in-memory diffs with the existing \`Studio::DocumentGenerationPlan\`. Changed/new/no-longer-retained synthetic candidates become human **assessment questions only**; unchanged claims do not create a revision request, and missing coordinates never authorize deletions.
- All future document artifact types and missing prerequisites are taken from the deterministic planner with \`evidence: {}\` — no fictional triage becomes a client-verified fact, document approval or permission to generate.
- No HTTP, database migration, document bytes, artifact revisions, real client data, provider billing or production access. [Slice G runbook](RC038_SLICE_G_SYNTHETIC_DOCUMENT_REVISION_IMPACT.md). Acceptance requires exact-HEAD CI/security and isolated Linux Mint Rails tests. RC-039 Project Hub and RC-040 actual Document Factory remain subsequent gated releases.


## RC-039 Slice A — test-only Project Hub board contract (2026-11-12)
- First independent **stacked Draft PR** above accepted RC-038, without changes to RC-038 itself. Read-only \`Studio::SyntheticProjectHubBoardPreview\` exposes four fictional lanes and nine future document-planning cards with unmet prerequisite edges derived from \`Studio::DocumentGenerationPlan\`, using only test environment and explicit synthetic opt-in.
- Owner/client/intake ACL checked again on every call; project and customer free text are never returned. All cards remain blocked for generation, no clients, tasks, milestones, schedules, approval, money, AI, HTTP, or persistence.
- [Slice A contract and acceptance runbook](RC039_SLICE_A_SYNTHETIC_PROJECT_HUB_BOARD.md); exact-head CI/Security and owner's Linux Mint tests required. **Not an actual Project Hub UI or persistent kanban**; further slices will require reviewed tenant-scoped models, E2E permissions, Turbo/Stimulus operations, keyboard a11y, and a project-only calendar.


## RC-039 Slice B — synthetic-only persisted card transitions (2026-11-12)
- \`Studio::SyntheticProjectCardWorkflow\` now supports strictly test-only creation, listing and serialized state transitions of scoped **fictional metadata cards**. DB composite client/intake foreign keys, fixed artifact catalog and nonapproval states are enforced by additive tables and checks. Append-only transition receipts and expected-version checks reject stale/invalid operations.
- No client-facing or owner HTTP endpoints, UI, real project data, due dates, board drag/drop, document approval or calendar coupling. [Slice B runbook](RC039_SLICE_B_SYNTHETIC_PROJECT_CARDS.md).
- Gate remains exact-head GitHub CI/Security and isolated Linux Mint tests. Production deployments, full private storage/consent and future real-role ACL need separate review.


## RC-039 Slice C — test-only owner HTTP board operations (2026-11-12)
- A strictly test-environment registered JSON HTTP contract (GET closed board+cards, POST fixed fictional catalog card, PATCH state with exact optimistic version) reuses RC-039 Slice A/B and existing DB-backed owner session. No routes in development or production, and runtime hard-denial independently verifies production/test predicates.
- Private no-store/nosniff/referrer response headers, per-request workspace/client/intake scoping, denied revoked/foreign owners, opaque fixed metadata, blocked document generation, no arbitrary card fields or real content. Request tests exercise read/write/ACL/CSRF/version conflict/forged approvals.
- No HTML/Turbo/Stimulus UI, project scheduling, real user tasks, comments, client access, storage/AI/provider use. [Slice C test-only HTTP runbook](RC039_SLICE_C_SYNTHETIC_PROJECT_HUB_HTTP.md). Exact-HEAD CI and Linux Mint owner regression are mandatory.
