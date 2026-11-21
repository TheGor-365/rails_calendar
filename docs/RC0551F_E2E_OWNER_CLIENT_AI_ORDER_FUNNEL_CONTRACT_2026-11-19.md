# RC055.1f — E2E owner ↔ client AI order funnel contract (2026-11-19)

Status: **development specification**, not a claim of implemented behavior. Local fictional pilot only until security, delivery, billing and persistence release gates are met.

## Truth on 2026-11-19

- E2 uses one-time owner-issued 256-bit invitation, fragment-only token, filtered POST preview, encrypted cookie, atomic verified-client claim, one canonical ProjectIntake, and owner/client ACL. Its draft starts from `seed_title`, `seed_project_type`, `seed_goal` and selected published offering versions.
- Independent verified-client creation uses `/client/requests/new` and `client_requests#create`.
- Existing AI OperationRegistry has **exactly four** authorised purposes: `service_copy`, `intake_questions`, `client_reply`, `plan_outline`. Do **not** display unsupported operations as working.
- Existing dock navigator handles allowed page navigation only. Files, Information, Dates, Tasks, Archive are **not yet implemented tool plugins**; no fabricated search results or buttons.
- Owner AI calls are paid; owner must explicitly opt in per operation. Client AI proposal generation needs its own provider, budget, privacy and consent boundary.
- Existing Rails Calendar is a local pilot with no production-ready notification delivery guarantee. Never send a real SMS/email or expose local addresses without authorised delivery setup.
- Visual reference: `WHITE_ATLAS_DESIGN_SYSTEM_V1_2026-11-14`, existing `/workspace`, owner/client cabinets, current SCSS cascade. No global redesign.

## UX requirements: common

1. White Atlas page hero, workflow steps, actionable section cards, meaningful Bootstrap icons, existing rc-select; subtle CSS state transitions; accessible keyboard + reduced motion.
2. Task composer must be structured-first: user can select categories and default options without writing paragraphs; optional notes and explicit "leave open / client decides / owner decides" per section.
3. Owner and client see a **versioned, reviewable shared draft**, not private raw AI context or a purported agreement.
4. Every visible action has a real state transition, persisted in DB and covered by role-bound tests. Do not show simulated notifications or provider/tool results.
5. Autosave is scoped to the correct canonical intake; no silent duplicate intake, and no data loss on refresh.

## Owner-started order workflow (E2+)

Owner workspace → structured task draft → (optional file attachment, separately authorised storage) → manual preview → optional paid AI **draft** with explicit consent → owner reviews/edits → invitation recipient selector → delivery confirmation → guest safe preview → verified client claim or client registration → client edits facts and marks unknowns → intake questions/AI assistance (separate consent) → client submits one canonical intake → owner inbox unread badge → owner drafts spec/revisions → client reviews published spec. No acceptance of price/contract is implied.

Recipient/delivery channels must be explicit states: `manual_link`, `existing_account`, `email`, `sms`, `messenger`. Only `manual_link` exists in E2 today. No "sent" or badge until enqueue + delivery/in-app record exists. A local `localhost` link is not a remotely reachable client invitation.

## Client-started order workflow (E1+)

Sign up / verify → client cabinet → new request → choose published services or free-form goal → structured facts/unknowns and optional guidance → save draft → review → submit → owner inbox → scope clarifications → owner-approved versioned spec → client reviewed acknowledgment. Preserve existing E1 fallback and legacy owner intake route; do not duplicate ProjectIntake.

## Proposed taxonomy (to add as persisted, validated versioned fields, not only a string)

- **Task kind**: bugfix, feature, CRUD/admin, forms, REST API, integration, test, performance, security, deployment, design, content/data processing, automation, AI.
- **Frontend/UI**: HTML/ERB, CSS/SCSS, Bootstrap, Hotwire/Turbo/Stimulus, JavaScript, Vite, Vue, responsive/accessibility.
- **Backend/data**: Ruby, Rails, PostgreSQL, Redis, REST/JSON, migrations, jobs, validations, background tasks.
- **Operations**: Docker, GitHub Actions, Railway, VPS, domain/DNS, SSL/TLS, backup/restore, monitoring.
- **Scope**: current issue, affected screens/modules, reproducibility, dependencies, expected deliverables, acceptance criteria, exclusions, deadline *preference*.
- **Decision authority**: owner suggested / client confirmed / client unknown / owner discretion / client discretion / not applicable.
- Custom freeform addition per category must be bounded, sanitised, labelled as unverified, and never silently promoted to approved capability.

Taxonomy is a UI suggestion, not evidence that an owner knows every listed technology; owner public profile and offerings remain authoritative. Client-facing preview displays only approved public offerings and explicitly shared task facts.

## Data architecture, minimum follow-up slices

### E2.1 — schema and structured task drafts
Add versioned `intake_brief_revisions` (or carefully scoped JSONB with typed validator and optimistic revision) owned by ProjectIntake/invitation, with `author_role`, `version`, `taxonomy_revision`, `facts`, `review_states`, `source_kind` and timestamps. Owner's seed remains immutable evidence. Claims transfer structured copy into same ProjectIntake atomically. Server validates whitelisted keys/length/role, no HTML/SSRF URLs. Migrations **only** after explicit review DB confirmation.

### E2.2 — AI-assisted structured draft
Whitelisted purpose registry + prompt templates with schema validation and explicit per-call context projection. Responses create `proposed` revisions, never auto-publish, auto-send or overwrite user edits. Owner approved public facts only; no client files/private owner notes sent automatically. Track provider, model, request hash, cost and consent. Client assistant requires isolated client token/budget and ACL.

### E2.3 — tool plugins with actual execution semantics
Server registry: `files`, `pages`, `information`, `dates`, `tasks`, `archive`. Each entry needs capability status, permission boundary, input schema, server executor, audit and output provenance.
- Pages: current owner-only allowlisted navigation can be linked immediately.
- Files: only explicit attachments with malware/size/type guard and private storage; never global file access.
- Information: approved public service/profile summaries plus scope-specific already-visible business data.
- Dates: local calendar read model scoped to owner, timezone, calendar conflicts; write requires explicit permission.
- Tasks: ProjectIntake and milestones read model; modification with version checks, owner/client roles.
- Archive: scoped version/history search, not broad filesystem access.
A chip may insert a structured selection into the composer only when the server can execute that capability; no invented results.

### E2.4 — delivery and notifications
In-app notifications with DB state + unread badge and recipient ACL. Delivery adapters for email/SMS/messenger behind explicit configuration, consent, opt-out, anti-spam/rate limits, transactionally queued outbox, delivery state, URL domain verification. Manual-copy remains available. No SMS/email without tested accounts.

### E2.5 — joint document funnel
Versioned spec package: overview, goals, deliverables, acceptance, unknowns, exclusions, estimates flagged nonbinding, milestones, revision history; user review separate from contract acceptance and billing.

## Acceptance gates per slice

- Access: owner vs client vs guest; cross-tenant requests return 404; expiry/revoke/replay, no token logs or referers.
- Persistence: refresh, duplicate POST, concurrent claim, cancel/edit/autosave, server validations; no lost data.
- UI: 1440/1280/768/430/390/320 widths, no horizontal overflow, keyboard, Turbo cache, no abrupt dock closure, viewport-capped scrolling, prefers-reduced-motion.
- AI: default-off; no paid call without explicit per-request approval; no unapproved source projection, no raw prompt sent to other roles.
- Tests: controller + system + CI + security **on exact head SHA**; separate user browser screenshot acceptance. No changes to original port 3001 or Railway release.

## Implementation order

1. **Current safe visual slice:** dock interaction/height/real four operations and invitations White Atlas visual shell. No new DB or provider calls.
2. Structured draft facts + taxonomies and explicit decision states (server persistence, tests, locales).
3. Client structured review and canonical intake revision flow.
4. Consent-based AI draft generation with typed output and budget/ACL.
5. Real tool registry + incremental providers, then notifications/outbox.
6. Full spec package and release gates.

Do not misreport slices 2–6 as implemented.
