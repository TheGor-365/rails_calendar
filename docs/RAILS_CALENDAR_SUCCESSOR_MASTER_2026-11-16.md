# RAILS CALENDAR — SUCCESSOR MASTER + FULL ROADMAP
**Checkpoint:** 2026-11-16, Asia/Yerevan. Primary repo https://github.com/TheGor-365/rails_calendar.
**Always refresh:** GitHub PR #70 head SHA, CI, status, git status, and owner newest screenshot on resumed chat. This file is a handoff, not evidence of a local deployment/merge.

## 0. Agent contract
You are the owner's exacting senior Ruby on Rails engineer, technical lead, UX engineer, QA and product architect working on the real Rails Calendar AI Workspace repository. Speak Russian, be concise, deliver code/tests with GitHub connected tools, and give the owner 1–3 concrete steps to the next screenshot/terminal output. Do not ask already answered questions. Do NOT fabricate links, test output, accepted UI, production actions or client orders.
- Primary KPI: a safely functioning client-to-provider service workflow, not a number of PRs.
- User performs terminal commands and browser clicks; you may prepare branches, commits, fixes and Draft PRs with connected GitHub tools.
- Preserve source, data and backups. Never merge, deploy to Railway, migrate production, reset local data, delete any branch/file/attachment, trigger paid Grok, publish externally, or send customer messages without explicit authorization.
- The local owner holds a real personal avatar now. Respect privacy. Never ask for secrets, API keys or credentials.

## 1. Sources of truth and coding environment
Read these sources IN ORDER before beginning new implementation:
1. This file and docs/RC0551E_PREMIUM_AI_WORKSPACE_AVATAR_2026-11-16.md.
2. Actual PR #70, source file contents and final HEAD GitHub CI results. Latest browser screenshots from the owner take priority for visual truth.
3. docs/WHITE_ATLAS_UI_CONTRACT_2026-11-15.md — mandatory styling/interaction contract. Existing app/SCSS and accepted /workspace, /workspace/cabinet, /workspace/practice, RC055.1b /workspace/services show visual target.
4. docs/ADR003_AI_FIRST_INTAKE_OFFERINGS_UNREAD_PROJECT_FILES_2026-11-15.md — original complete commercial funnel ADR. Its 15 Nov "not implemented" section is HISTORICAL; reconcile with implemented features below.
5. docs/RC0551D_CATALOGUE_COPILOT_AVATAR_2026-11-16.md; docs/RC0551C_PRIVATE_SERVICE_MEDIA_2026-11-15.md; docs/RC0551_OWNER_VERSIONED_SERVICES_2026-11-15.md; docs/RC0550B_CLIENT_CLARIFICATIONS_2026-11-15.md, plus earlier PRs for specifics.
6. docs/RAILS_CALENDAR_DEVELOPMENT_ROADMAP_2026-11-07.md and older successor master are HISTORY only, not current operational status.

Repo: TheGor-365/rails_calendar. Runtime in Draft chain Ruby 3.4.12, Rails 8.1.4.1, Puma 8, PostgreSQL 16.11, Hotwire/Turbo/Stimulus, Sass + Bootstrap Icons, JS esbuild, Minitest + Capybara/Chrome.
User works in Linux Mint:
- working tree: ~/rails_calendar_mvp_release_20261112
- local preview URL: http://127.0.0.1:3012
- environment: ~/.config/rails-calendar/preview-3012.env (do NOT request contents)
- local dev DB: rails_calendar_mvp_preview_20261112, user gor, Unix socket /var/run/postgresql
- normal Chrome owner account: admin@example.com
- incognito verified pilot client: client-preview@example.test
- local session policy was verified enabled, 336-hour window; not production policy.
- User terminal latest branch is NOT established for PR #70 until user shows git status; screenshots of RC055.1d are evidence only of browser UI.
Do not run CLI on user's machine yourself. Always verify clean tree, expected branch SHA and exact DB/role before any migration. db/schema.rb may be regenerated with unrelated drift after migration; save snapshot and inspect first. No new DB migrations in PR #70.

## 2. GitHub status and review gate
- All work lives in chained, open Draft PRs. main and Railway production remain unaffected. Do not merge/force-push.
- Prior sequence: #53–#59 RC054 client flows/owner specs, #60 RC055.0 unread, #61+ RC055.0b/c/d/e owner+client messaging/navigation; #68 RC055.1c private media; #69 RC055.1d catalogue AI, avatar and owner preview.
- PR #69 URL: https://github.com/TheGor-365/rails_calendar/pull/69; HEAD 035ae9e9d2d625e74016fe1c6b00fa52d56286ec, Rails 271/4035, Chrome 39/548, Security PASS as verified in preceding chat, but owner REJECTED its AI page and oversize avatar panel.
- PR #70 URL: https://github.com/TheGor-365/rails_calendar/pull/70, branch feat/rc0551e-premium-ai-workspace-avatar-2026-11-16, parent #69, Draft. New premium AI UI, avatar pencil/crop, reusable AI UI links. The head will change as CI fixes land. Fetch final SHA and checks; NEVER trust this document as live CI state.
- Important: do not assume all older PR ancestry or historical status from the 07 Nov roadmap is still current. Check actual refs and status.

## 3. Implemented and actually observed
### Existing calendar and accounts (RC001–054)
- Calendar month/day/hours, consultation forms, 24h grid, overlap advisory, rescheduling, UTC contract, access controls and responsive White Atlas UI in Draft stack.
- Local owner and verified-client sessions, setup interview with six saved sections, versioned approved professional context v1, skills/capability editing, AI spend ledger with explicit budget; owner AI reports remain private.
- Client synthetic request creation, client reply, owner reply, versioned T3 draft/approved spec UI and request-side navigation. All pilot data fictional; no real commercial acceptance.
- RC055.0 owner-specific persistent unread badge; owner request detail marks displayed client messages seen. Listing does not clear badge.
- Local accounts are separate authenticated roles; legacy admin principal != owner session.
### Owner services RC055.1–055.1e
- 9 private services automatically generated from owner-approved profile v1, with source capability and delivery mode; manual versioned draft, approve/finalize, internal enable, separate logged publication pointer. Not publicly visible to clients yet.
- RC055.1c Active Storage service media: owner-scoped upload, MIME/size checks, caption, archive, manual approval; banners/images, audio/video/docs in owner-local pilot. No automatic AI file access. Private banner render on owner catalogue cards.
- RC055.1d first owner-only Catalogue AI Copilot: explicit paid Grok check (max 12 services, 22KB payload); AiSpendLedger 0.10 USD per-call reserve, global 2 USD cap/daily+subject caps. JSON schema/strict validation, source digest and immutable versions, compare proposals, apply single or atomic batch to draft only. No auto-finalize/publish. UI initially not owner-accepted.
- User screenshots 2026-11-16 show banner previews on four owner cards marked "pending", working /workspace/services/ai with latest audit "0 suggestions", /workspace/cabinet with uploaded private avatar and visible cumulative AI spend $0.01374. Do not infer independent model QA or any client visibility from these screenshots.
- RC055.1e PR #70 improves exactly that AI page, adds functional GET filters, a reusable UI action registry linking to existing review routes, and a compact avatar-pencil popover with 1:1 center-crop before upload. Requires QA and explicit owner acceptance.

## 4. Local recovery and privacy
- Successful full restore of preview PostgreSQL 16 custom archive 2026-11-15 before RC055.1c:
  /home/gor/.local/share/rails-calendar/backups/preview-before-rc0551c-20261115_233717.dump
  SHA256 c68bf2b022e8105d0bcd99c400a9cd0fcdd762bada656ba05fb6b0984a253780.
  Source/restore counts 2 users | 2 intakes | 5 messages | 9 services | 9 service versions; RC0551C_RESTORE_PASS confirmed.
- That archive predates subsequent banner/owner-avatar files and is NOT sufficient to restore newer DB records; PostgreSQL archives never contain local Active Storage file bytes.
- New backup required BEFORE any later migration/release: PostgreSQL archive with PG16 pg_dump, pg_restore --list, isolated restore with transaction, count comparison; PLUS private snapshot of storage/ (and production private object storage policy). Never overwrite the previous backup or publish it.
- User retains personal picture locally; do not send files to Grok or external apps. Disable Active Storage public blob URLs; owner-scoped file endpoints only. Public client service catalogue is not implemented.

## 5. End-to-end product model
ProfessionalContextSnapshot / ProfessionalCapability (private owner-supplied claim)
  -> ServiceOffering / immutable OfferingVersion / explicit approval / internal enabled
  -> client-visible **published** version (FUTURE RC055.2)
  -> ProjectIntake (client facts, selected version or "Other")
  -> qualification and evidence (RC056)
  -> versioned client/owner questions + answers (RC056)
  -> owner-approved scope/requirements (RC057)
  -> owner-approved quote, schedule, payment feasibility (RC057)
  -> accepted Project/Task/Milestone and calendar projection (RC058)
  -> private versioned ProjectFile/ProjectArtifact, download and handoff (RC058)
  -> release, acceptance, truthful payment state (RC059+).

Never conflate draft, reviewed, approved, enabled, client-visible, published, client read, scope accepted, paid or released. AI-generated text is not a customer statement, a verified capability or a legal promise.

## 6. Full remaining roadmap, ordered
### P0 RC055.1e final QA and refinements — CURRENT
1. Wait for final HEAD Rails/Chrome/Security CI on PR #70; inspect failures/logs, fix code in same branch and retain Draft. Check tests count and exact SHA.
2. User safely switches working copy to PR70 after git status + preserving schema drift; bundle install, yarn build, yarn build:css, bin/rails restart. No migrations.
3. Visually accept /workspace/services/ai at desktop 1440 and mobile 390/320, including empty state when Grok suggests nothing, real filters when seeded results exist; check tab navigation/focus and no overflow. Confirm /workspace/cabinet small square photo + pencil popover, upload/crop/owner-only file route, no separate avatar block. Browser screenshot acceptance required.
4. Do NOT rerun Grok merely for UI: real paid call occurred; existing audit shows 0 suggestions, so use test fixtures for positive-results screen in CI.
### P1 RC055.1f: true reusable AI action backend for owner pages
- Define named, server-approved operation registry with per-operation inputs, output schema, system prompt version, privacy labels, redaction, consent class, cost cap, idempotency and role permissions. No generic arbitrary model command that can read/modify all owner data.
- Add run/review/apply service with immutable AiActionRun + AiSuggestion (or reuse ledger with explicit adapter), version/source digest and stale conflict. Evidence provenance, compare diffs, human apply, undo via versioned revisions, and audit log.
- Actual owner page AI buttons/actions in phases: profile/interview, competencies, each service and catalogue-wide; then owner intake detail, manual spec editor, client-facing replies with human send approval. Each has useful scoped task, not an inert button. Manage presets/prompts securely, no exposed keys, no user bypass of system safety. File access only after independent per-asset consent and safe extraction/scan.
- Test zero-budget/manual fallback, owner/client/foreign ACL, prompt injection, stale changes, retries with uncertain billing, cross-snapshot leakage and 320px UI.
### P2 RC055.2 client services
- Explicit owner selection of APPROVED, enabled and client-visible offerings; separate public-facing publication gate, no private notes/limitations exposed.
- Client can browse service cards and choose exact immutable version in /client/requests/new; "Other / describe your work" manual fallback. Preserve existing website/redesign/rails_bugfix/api_integration enum compatibility; store historical offering version/category on new intakes. Client rights strict; no prior requests rewritten; mobile no horizontal scroll.
### P3 RC056 qualification/manual + AI
- First deterministic eligibility/hard no-go, service/owner snapshot binding and verified known facts; owner reviewing fit/risk/questions.
- Ask one useful non-repeated question. Owner approves/edits/skip/sends; client replies; store source/version/timestamps.
- Optional paid Grok with explicit consent, scoped redacted input, JSON schema, ledger/dedup, no speculative promises. 429/timeout uncertain billing hold, manual deterministic fallback at zero budget. No fake diagnosis.
### P4 RC057 scope and contract
- Versioned spec/TZ, distinguish mere read receipt from scope acceptance; editable owner-approved scope, revision history/client change requests and no retroactive mutation.
- Price, currency, deliverables, deadlines, tax/contract language only after owner confirmation; quote/proposal versions and acceptance; real payment-route feasibility rather than "card exists".
### P5 RC058 project execution/files
- Model Project/ProjectTask/Milestone; approved scope/project status, calendar integration as projection, tasks, progress events, deliverable acceptance.
- Authorized private file versions, MIME/size validation, malware scanning strategy, retention, checksums, explicit sharing per asset and download audit. Production persistent object store with restore testing; no Railway ephemeral disk dependency.
- Owner-reviewed exports ZIP/MD/PDF, truthfully sourced from approved documents and real file outputs; no fabricated tests or financial status.
### P6 RC059 hard release gate
- Consolidate Draft ancestry, check dependency/security, run full Rails/browser/security suite, cross-role penetration tests, staging restore of production-shaped data/storage, migration audit, rollback and disaster recovery drills.
- Domain, TLS, email verification, deliverability, privacy terms, KYC/payment legal constraints, budget/cost alerting, observability, data residency, retention and backups. Explicit owner approval before any merge/deploy/production migrations.
### P7 post-release
- Evidence-based pilot with real qualified leads, paid invoices and deliverables, monitoring and operational playbooks; modular verticals only after Rails service business workflow proven. Prevent feature-count from replacing revenue/safety KPIs.

## 7. Invariants, implementation & QA standards
- GitHub via tools.mcp__GitHub__* and code-mode: read exact source, scoped branch from latest verified parent, atomic create_tree/create_commit/update_ref with expected_sha, Draft PR stacked on parent, wait for Rails Chrome Security on final SHA. No fake CI. Fix failed assertions rather than skipping.
- White Atlas typography Inter/Segoe, tokens in _rc_design_system.scss, _rc_workspace_surface.scss, _rc_owner_cabinets.scss, _rc_service_offerings.scss, RC055.1e _rc_owner_ai_workspace.scss. Existing surface-panel, rc-action, Bootstrap Icons, compact density, 2px restrained hover and focus rings, mobile parity 1440/1280/768/430/390/320. No separate design system, no gratuitous giant blocks.
- UI gives primary actual next action, readable status/source/age; negative restrictions as subtle red dots and calm descriptions; reduced motion/accessibility.
- AI never silently runs, approves, publishes, sends messages, spends money or modifies final versions. Price/scope/feasibility verified by owner. Manual fallback always.
- Cross-tenant single-owner pilot is not a real multi-tenant architecture. Future tenant-scoped foreign keys/authorization required. Verify client access separately.
- Test: Rails unit/model/controller, system/Chrome, security, private routes/foreign ownership, stale version/conflicts, malformed outputs/prompt injection, browser responsive and keyboard.
- Any new migration requires isolated verified PostgreSQL+private blob backup first; reconcile schema.rb only after diff; never drop DB/reset, and do not touch Railway without release gate.
- End each stage with: verified facts | links/SHA | status of code/CI/visual/local/staging/prod | unresolved blockers | next 1–3 owner actions.

## 8. Next task for successor (do, do not merely plan)
1. Open PR #70 HEAD and exact CI. If failing, inspect logs, implement smallest fix and rerun all checks.
2. If green, instruct owner on safe branch transition from their actual git status, preserving schema.rb and local storage; run bundle+assets+restart, no migration; request 2 screenshots of premium AI page and compact avatar pencil/popover.
3. Apply UI fixes if owner flags them. Then create separate Draft PR for RC055.1f backend named AI action registry and first substantive on-page workflow, keeping all manual approval gates.
