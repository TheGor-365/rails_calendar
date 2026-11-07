# Rails Calendar → AI Service Operating System — development roadmap

**Checkpoint:** 2026-11-07 (Asia/Yerevan), RC-020 desktop Reschedule navigation accepted; RC-021 CI/Security PASS; RC-022 Draft admin-only reschedule history and ADR-002 capacity policy proposal. **Source of truth:** [repo](https://github.com/TheGor-365/rails_calendar), [RC-012 PR](https://github.com/TheGor-365/rails_calendar/pull/12), [Notion owner vision](https://app.notion.com/p/4102cdc8e76581a7b83fd889ea0846bd), [RC-011 checkpoint](https://app.notion.com/p/4102cdc8e76581eaa500d6aab39996a6).

**Product contract:** evolve the existing Rails Calendar, do not rewrite it. The calendar becomes the visible scheduling layer of an AI-assisted service-delivery system for the owner's actual Ruby on Rails freelance work. Initial vertical: Rails debugging, CRUD/forms, API/PostgreSQL, tests and small integrations. Later professions require versioned playbooks, not cloned apps. The system must not invent paid engagements, commitments or approvals.

## Permanent engineering principles

1. **Mobile feature parity:** every meaningful desktop action, permission and feedback path must also be reachable on 320/390/430px mobile with clear tap targets, focus/keyboard support and no hidden required action behind unexplained scrolling. Layout may reflow; capability cannot disappear.
2. **Visible text + restrained icons:** Bootstrap Icons already pinned in the app; Slate & Tide design tokens. Icon-only controls require explicit accessible names; ordinary actions retain short visible labels. Decorative icons are `aria-hidden`. No emoji pseudo-buttons or new icon dependency.
3. **Proof before status:** only source code + tests + user visual inspection can qualify a feature as accepted. GitHub green CI does not prove local/production UX.
4. **User & data safety:** Draft stacked PRs; no merge/production deployment, paid Railway setup, DB deletion, wide resets or process kills without explicit release gate; keep auth/ACL server-side; never expose actual client secrets in public demo.
5. **Business source of truth:** requests, approved scope versions, commitments, project milestones and audits are durable business records; the calendar is their timeline projection, not the entire domain model.
6. **AI assists, humans approve:** AI output must be validated, versioned and reviewable. AI cannot accept budgets/scope, promise fixed deadlines, or act on external systems without user authorization.

## Current delivery register

| Unit | Description | Status/evidence |
|---|---|---|
| RC-001 / PR #1 | Baseline calendar queries, model validation and CI | Implemented in Draft stacked branch, not merged |
| RC-002 / PR #2 | ENV-backed admin session and server-enforced public read-only ACL | Implemented + tests; manual CRUD still to verify |
| RC-003 / PR #3 | Ruby 3.4.12 / Rails 8.1.4.1 upgrade | Implemented + CI; unmerged |
| Duplicate PR #4 | Alternate RC-003 | **SUPERSEDED — DO NOT MERGE** |
| RC-006 / PR #5 | Login throttling and HTTPS policy | Implemented; multi-instance production behavior not reviewed |
| RC-004 / PR #6 | Accessible responsive forms/calendar | Implemented; no final consolidated release |
| RC-007 / PR #7 | Input/date rules + Slate & Tide foundations | Implemented, CI |
| RC-008 / PR #8 | 24-hour day schedule + admin manual scheduling | Implemented, CI |
| RC-009 / PR #9 | Compact agenda visual system | Implemented, CI |
| RC-010 / PR #10 | Continuous multi-hour event layout, overlap lanes and hour detail | Implemented, CI |
| RC-011 / PR #11 | Safe local boot, day/event deep links, separate list/detail UX | CI+Security success; user desktop screenshots show NameError resolved |
| RC-012 / PR #12 | Seven visible mobile columns, month event list and mobile feature parity | CI+Security success; user screenshots at 430px show working day/event navigation |
| RC-013 / PR #13 | Restrained icon-labeled controls and touch/focus styling across existing screens | CI+Security SUCCESS; owner mobile detail screenshot shows icons |
| RC-014 / PR #14 | Persistent five-tab dock and single-row detail actions | **Local visual PASS** on mobile after RC-014b; authenticated New screen confirmed; CI/Security green |
| RC-015 / PR #16 | Minute-only input/validation, unchanged legacy timestamp retention, record-specific delete confirmation | CI+Security SUCCESS; owner screenshots show **minute-only form, successful #4 creation, index and anchored day card**. Record-specific delete confirmation still needs manual QA; [safety note](RC015_MINUTE_PRECISION_DELETE_SAFETY_2026-11-07.md) |
| RC-016 / PR #17 | Explicit UTC storage/display baseline, midnight/DST regressions and expired/logged-out ACL | CI+Security SUCCESS: 76 tests/601 assertions. [ADR-001](ADR001_UTC_TIMEZONE_CONTRACT_2026-11-07.md); regional client timezone UX pending decision |
| RC-017 / PR #18 | Private-by-default production calendar read mode, explicit demo-only public opt-in | **CI+Security SUCCESS** (82 tests, 636 assertions); owner 07 Nov incognito screenshot confirms guest root → admin login in private mode; [privacy gate](RC017_PRIVATE_CALENDAR_RELEASE_GATE_2026-11-07.md) |
| RC-018 / PR #19 | Shared PostgreSQL fixed-minute admin login throttle (atomic, fail-closed); additive rate-limit table | **CI+Security SUCCESS**. Owner `24bc1ca` checkout, backup read check, additive local migration, retained #3/#4 and 6-call model decision `false×5,true` **PASS**. Real HTTP 429, proxy trust and staging remain open; [gate](RC018_SHARED_LOGIN_THROTTLE_2026-11-07.md) |
| RC-019 / PR #20 | Exact durations, safe title search, UTC date/status filters, pagination and mobile parity | CI+Security SUCCESS (99 tests / 777 assertions); **owner desktop screenshots PASS** for #4 duration, title and UTC date filters; new mobile screenshots pending. [Acceptance](RC019_CONSULTATION_SEARCH_DURATION_2026-11-07.md) |
| RC-020 / PR #21 | Nonblocking overlap warnings on details/forms and one-hop authenticated reschedule links | **CI + Security SUCCESS**; **owner desktop screenshots PASS** for Reschedule on #4 with prefilled 11:00–12:40 UTC. Cancel and mobile QA still open; [RC-020](RC020_OVERLAP_ADVISORY_RESCHEDULE_2026-11-07.md) |
| RC-021 / PR #22 | HTTP auth/fail-closed regressions, delete Cancel Selenium test, restore/proxy/tenant SOP | **CI+Security SUCCESS** on code `cf67910`: 113 tests/881 assertions; no actual stage restore or live proxy/CSRF verification; [RC-021 release gate](RC021_P0_SECURITY_RECOVERY_GATE_2026-11-07.md) |
| RC-022 / PR #23 | Transactional administrator reschedule audit with reason, old/new UTC snapshots, admin-only history and mobile tests | **CI+Security SUCCESS** on code `e96c366`: 123 tests/982 assertions; **additive migration NOT applied to owner local/Railway**, manual stage/privacy QA pending; [RC-022](RC022_RESCHEDULE_HISTORY_2026-11-07.md) / [ADR-002](ADR002_RESCHEDULE_AUDIT_CAPACITY_2026-11-07.md) |

All these PRs are Draft and stacked; `main` and production have not been changed by this program. #4 is a superseded duplicate (DO NOT MERGE).

## Phase A — finish the existing calendar (P0; before public launch)

### A1. RC-014b — fixed mobile dock / CSS freshness (VISUAL ACCEPTED)
- **Verified** [CI run 42304835490](https://github.com/TheGor-365/rails_calendar/actions/runs/42304835490) and [Security run 42304835617](https://github.com/TheGor-365/rails_calendar/actions/runs/42304835617) on SHA `af850af347c30d632058ca7464f6b3a1680a45f3`: 54 Rails tests/352 assertions + 15 Chrome tests/172 assertions, 0 failures/errors/skips. Chrome at 320/390/430 and desktop. Assert browser-computed CSS release marker, fixed viewport bottom even after long-page scroll, 5 equal tabs centered within a max-430px dock, required safe-area padding and one-row consultation actions. Verify guest/new authentication gate.
- Test Month ⇄ Day → Hour and Event → details → anchored Day, Today, admin sign-in, create/edit/delete, cancellation.
- User screenshot at 430px before RC-014b showed plain underlined dock links in document flow, despite GitHub browser CI showing fixed CSS. Root cause **not yet confirmed**, likely local CSS asset stale. Launcher now checks a version marker inside the built Sass bundle; use hard reload with Chrome cache disabled if necessary. Owner accepted mobile dock on new screenshot; 320px and full cross-device keyboard/touch audit remain release checks. Verify icon font, labels, focus/touch and no hidden content.

**Exit:** owner accepts visual style and controls; no failures or hidden functionality.

### A1b. P0 CRUD local incident / precision (RECOVERY DECISION CLOSED)

- **Manual P0 confirmed:** admin sign-in, public month/day display, admin create #3, updated #3, record index and calendar deep links.
- **Disposition:** the original **#2** was deleted by mistake rather than temporary **#3**. Read-only Rails runner confirmed only #3 remains; owner explicitly confirmed #2 was an unneeded demonstration and **chose not to restore it**. This closes the recovery decision, not the underlying user-error risk. Do not delete #3 without further explicit authorization.
- RC-015 changes the minute-only HTML fields (`step=60`, explicit value to HH:MM), server precision validation and preservation of legacy seconds for unchanged times; improves the confirmation with the exact title, ID and date/time. Reversible deletion/audit is a future schema decision, not implemented here.
- **Exit:** local recovery decision resolved; RC-015 CI/Security green; owner demonstrated HH:MM + new #4 consultation, calendar/index navigation. Deletion confirmation still needs manual UI check. No merge/Railway before those gates.

### A2. Admin/security & data review (RC-017 READ PASS; RC-018 LOCAL MIGRATION + MODEL THROTTLE PASS)
- Test admin login/logout, wrong password, session expiry and explicit denial of POST/PATCH/DELETE to anonymous users; preserve real records.
- RC-017 makes production read routes private unless explicit synthetic-only public demo opt-in; owner screenshot shows intended guest redirect. **Important**: all records become readable when demo mode is on; no row-level/client privacy yet.
- RC-018 replaces per-process login throttling with shared PostgreSQL atomic counters, HMAC IP pseudonyms and fail-closed DB errors. Owner confirmed local migrated table and `false×5,true` synthetic threshold; **this does not establish HTTP 429 in an actual login browser flow**. Review migration in isolated staging with backup; schedule maintenance prune, verify reverse-proxy trust, cookies/CSRF, secrets/HTTPS and log redaction.
- Confirm duration and boundary behavior for midnight, empty days, simultaneous bookings and invalid input. Define cancellation/no-show/reschedule policies before adding states.

**Exit:** documented access matrix, negative tests and manual admin CRUD success.

### A3. Timezone and scheduling ADR (UTC BASELINE IMPLEMENTED)
- RC-016 pins existing UTC behavior; [ADR-001](ADR001_UTC_TIMEZONE_CONTRACT_2026-11-07.md). Regional admin/client display choice still requires approval.
- Define display/entry across Armenia timezone, DST in other locales, nonexistent/ambiguous wall times, half-open `[start,end)` intervals, event conflicts and daylight-length anomalies.
- Preserve stored instants and historical records in migrations. No silent timezone conversion.

**Exit:** reviewed ADR, timezone regression tests and clear UI labels.

### A4. Stack review & release gate
- Review commits and dependencies for PR #1→#18 (excluding superseded PR #4 and unrelated #15); squash/rebase only after explicit owner consent and backup.
- Verify staging DB migrations/data, restore/rollback procedure, health checks, 320/390/430 smoke, credentials, session policy and Railway resource costs.
- Production remains blocked until manual gate.

**Exit:** one reviewed, reproducible staging candidate with clean test/security status.

## Phase B — useful consultation product (P1)

**RC-019 desktop QA accepted:** owner screenshots confirm `Duration: 1 h 40 min` for #4 and both title/date-filter matches. Clear and mobile parity remain to be visually checked by owner (Chrome system tests green).
**RC-020 desktop visual PASS:** the owner opened #4 edit from list via Reschedule and saw original 13 Nov 11:00–12:40 UTC. No save/cancel confirmation yet; mobile screenshots pending. Only advisory half-open overlap detection is implemented; no hard booking conflict rule or automatic data edits before policy approval. See [RC-020](RC020_OVERLAP_ADVISORY_RESCHEDULE_2026-11-07.md).

- Distinguish **Month overview**, **Day 24-hour timeline**, **Hour details**, **Consultation record** and **all-records index**. Keep clear navigation and actions.
- Search/filter by date range/title, paginate large results, show upcoming and recent records, empty states, UTC/user-timezone labeling and scheduling conflicts policy.
- Authorized create/edit/cancel/rebook flows with explicit data validation and feedback, optional reminders only after notification design is approved.
- Tests for large/overlapping datasets, N+1 and public-private boundary. Preserve parity at 320/390/430/desktop.

**Exit:** one real repeatable consultation workflow, no duplicate-looking dead-end screens.

## Phase C — AI Intake vertical MVP (P2)

### C1. Architecture first
Prepare ADRs and additive schema migrations, not a replacement application. Proposed (not yet implemented): `Identity/User`, `ClientRequest`, `Conversation/Message`, `ProfessionalPlaybookVersion`, `SpecVersion`, `Estimate`, `Approval`, `Project`, `Milestone`, `Task`, `CalendarEvent`, `Notification`, `AuditEvent`. Confirm ownership, tenant scoping, visibility and lifecycle before migrations.

### C2. Narrow vertical workflow
1. Client submits Rails request → structured AI interview with clarifying questions and bounded tokens.
2. JSON schema validation → draft specification with goals, deliverables, assumptions, unknowns, acceptance criteria and out-of-scope exclusions.
3. Provider manually approves cost/time range and commercial terms; client approves a **specific immutable scope version**.
4. Approved project/milestone creates an authorized timeline event; the client sees only permitted information.
5. Event log, notifications and verified milestone acceptance; changes require re-approval.

**Exit:** tested E2E path on a synthetic, secret-free example, preserving approval evidence. Metrics: qualified leads, time-to-approved-spec, human effort, AI cost/lead, milestone completion and privacy incidents. Do not label demos as commercial orders.

### C3. AI safety and operations
- Structured schema, deterministic business validation, prompt-injection isolation, no raw untrusted tool instructions, quota and budget control, retries/idempotency and audit logs.
- Versioned prompts/playbooks for Rails first. Avoid arbitrary mass integrations or autonomous commercial commitments.
- Email/in-app channel first with explicit permissions and opt-in; external APIs later with minimized scopes.

**Exit:** privacy/security tests, low cost per validated request, clear human approval points.

## Phase D — web API / mobile client (P3)

- Rails monolith + PostgreSQL remains canonical; design authenticated versioned `/api/v1`.
- Web: Turbo/Bootstrap in shared design system. Mobile: separate Vite entrypoint consumed by Capacitor; ERB/Turbo pages are **not** a ready static Capacitor `webDir`.
- Ship Android and iOS only after web E2E passes; validate platform/store requirements, Xcode/macOS build availability, legal/privacy policies and budgets separately.

**Exit:** mobile/API parity tests and explicit store release checklist.

## Phase E — independent staging, portfolio proof and business use (P4)

- After owner approval, provision a separate staging environment (not other Railway apps); backup, restore and smoke tests first.
- Produce accurate RU/EN portfolio case with linked commits, real screenshots, CI logs, limitations and educational/demo classification.
- Use on real small leads only after privacy and pricing approval workflow is validated. Measure qualified requests and paid acceptance, not button counts or invented orders.

## Execution method for each increment

`readback current SHA + sources → define one user-visible acceptance outcome → write failing regression test where appropriate → smallest implementation → CI + Security on same final SHA → manual mobile and desktop QA → checkpoint with evidence`.

**Next 1–3 actions:** (1) RC-022 code CI/Security green: 123 tests/982 assertions on `e96c366`; recheck exact final HEAD after docs-only commits, keep Draft stacked onto RC-021. (2) Preserve owner-local `db/schema.rb` changes, `.tool-versions` and `vendor/bundle/` and **do not switch/migrate** the running local database until isolated staging backup/restore is tested and owner explicitly approves the additive schema. (3) Confirm the [ADR-002](ADR002_RESCHEDULE_AUDIT_CAPACITY_2026-11-07.md) distinction between an **admin-saved time change** and actual customer consent, then agree resource capacity/booking states and stale-edit/tenant privacy/HTTPS gate before automatic conflict enforcement.
