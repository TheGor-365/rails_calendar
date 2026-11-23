# RC055.1f C2.5a — One-home product information architecture (White Atlas)

**Date:** 2026-11-23. **Status:** design approved for a reversible local UI slice by the owner's explicit request; full IA migration NOT implemented, owner visual acceptance pending. No production release or migration authorization.  
**Inputs:** owner-provided screenshots (guest/owner, RU/EN, desktop 1649px and Chrome responsive 400px; 2026-11-23), owner's original concept/M1–M8 (uploaded 2026-11-23), source at code SHA `aecbe5e7df02064af172ade51a6882de36420ae3`, `config/routes.rb`, `app/views/layouts/{_nav,_mobile_nav}.html.erb`, owner workspace/cabinet/assistant/conversation and calendar templates, `docs/RAILS_CALENDAR_MVP_EXECUTION_ROADMAP.md`, `docs/RAILS_CALENDAR_PRODUCT_FIRST_DELIVERY_PLAN_2026-11-23.md`. Historical RC-032 status in the concept is stale; current code is the source of truth.

## 1. Evidence and UX diagnosis

- **Verified by owner:** `C24A_ASSETS_READY=PASS`; protected script printed `C21C_LOCAL_GROK_READY` and `C21C_DATABASE=verified_local_review`; Puma 8.0.4 / Rails 8.1.4.1 listening on 127.0.0.1:3002. No evidence of paid Grok call. Owner desktop shows calendar item 13 November 22:37 and on 19 November two distinct events inside hour 19:00–20:00; responsive 400px month and day are legible and have 5-item owner dock. This confirms rendering of these **specific states**, not every route at 320px/other roles.
- Guest month shown with 0 while owner month has private actions. **Expected ACL-dependent projection until proved otherwise**; do not publish private activity.
- Owner top navigation currently exposes Workspace, My cabinet, AI Workspace, Notifications, Library, Calendar, Today 24h, Consultations, AI request, Requests. Their labels describe different granularity: some are workspaces, some creation commands, some filtered views. Multiple places show cards pointing to the same content.
- `/workspace` is a dashboard **and** 8+ tool launcher; `/workspace/cabinet` is profile/settings **and** another 8-tool launcher; `/workspace/assistant` is controlled draft operations; `/workspace/assistant/conversations` is private AI chat. Distinct backends exist, but UI naming makes them look interchangeable.
- `/project_intakes/new` is a creation action whereas `/admin/project_intakes` is an owner inbox/outbox; they belong to the same **Orders** product area. `/workspace/invitations`, `/workspace/intakes/:id/requirements` are order-specific screens, not independent first-level destinations.
- `/consultations` is an appointment list; `/`, `/calendar/day`, `/calendar/hour` provide month/day/hour **schedule and private event projections**. A factual `occurred_at` event does not imply scheduled work; keep activity and calendar views explicitly labeled and differentiated.
- `/workspace/library` stores permitted projections/exports from canonical objects; `/workspace/activity` is a separate traceable journal. Owner screenshot of empty Activity History while calendar has events needs **source/filter comparison**, not a claim of lost data.
- Extensive screens (cabinet, services, AI draft composer, case review, requirement review) create long scroll and redundant intermediate pages. Existing AI conversations already use `turbo_frame_tag "wa-thread-workspace"`; reuse functioning patterns instead of introducing a SPA framework.
- Existing White Atlas tokens, Bootstrap Icons, typography, responsive mobile dock and authorization checks are **non-negotiable** visual/technical contracts.

## 2. IA target: seven destinations, only one primary home per operation

These are **product areas**, not seven new controllers or seven independent data stores. Routes stay backward-compatible during migration.

| Primary area | One question answered / canonical user intent | Existing source URLs and desired presentation |
|---|---|---|
| **Обзор / Workspace** | Что сегодня требует моего действия? | `/workspace`: short KPI and prioritized queue; no exhaustive duplicate tool catalogue. Deep links show object-specific action in its home area. |
| **Заказы / Requests** | Где новая заявка, клиент, приглашение, уточнения, ТЗ? | `/admin/project_intakes` becomes clear owner Orders entry, with filters `Входящие / Отправленные / Ожидают / Архив`; `/project_intakes/new` becomes `Новая заявка` inside Orders; invitation, quiz, source-traced R-ID, owner/client approval remain contextual steps. Client own requests remain strictly isolated. |
| **Проекты** *(planned, not a working top-level implementation)* | Что исполняем после согласования? | Future Project/Task/Milestone from exact approved spec; avoid fake navigation before source and ACL work. |
| **Календарь** | Когда назначена консультация или контрольная точка? | One nav destination `/` with in-area `Месяц / День / Консультации`. Appointment CRUD belongs here. Historic operation activity remains visible only with explicit `События/История` differentiation; future project schedule separate view/tab, not mixed fact vs intention. |
| **ИИ** | Где мои беседы и контролируемая помощь в работе? | Primary `/workspace/assistant/conversations` (persistent private chats) with `Инструменты` = existing `/workspace/assistant` (owner-reviewed draft actions), `Источники` and `История` as subviews. Contextual `Помочь с...` buttons within orders/services trigger same authorized operation, never a separate competing home. |
| **Библиотека** | Где созданные материалы и проверенные источники? | `/workspace/library` owns filters/search/source navigation and private generated downloads. Do not create separate hidden copies of spec/files. |
| **Кабинет** | Кто я, что настроено, какие приватные правила и расходы? | `/workspace/cabinet` owns owner avatar, approved professional context, interview/skills/settings, spending/consent. Move operational `Services`, `Orders`, `Library`, AI draft links to their primary area over later slices; show contextual shortcuts only where justified. |

`Услуги` is a **commercial catalogue** with owner editorial workflow `/workspace/services` and public `/services`; for MVP it can be a prominent secondary category under Orders, not duplicated inside Cabinet and Overview. If sales volume warrants a first-level destination, promote it without changing canonical source. `Уведомления` is a global inbox/badge drawer, not a top-level business domain; `История действий` is a global audit utility and deep link attached to sources. `Сегодня · 24ч` is a calendar view, not a separate app area.

**Single-entry rule:** navigation displays the canonical list screen; create button appears in that area and in context-specific object detail; when a shortcut exists elsewhere it links to the *same* form and same persisted source. No duplicated forms, ids, approvals or independent AI ledgers.

## 3. Simplified owner and client journeys

Owner: **Overview attention queue → Orders (outgoing service/invite or incoming draft) → scoped quiz/intake → AI suggestions/review → versioned R-ID spec with human approval → Project (future) → task, test evidence and handoff (future)**. Client: **published Services / valid Invite → verified client → own editable intake quiz → own request → precise spec revision approval → own project and deliverables (future)**. Guest sees only public marketing/allowed no-contact pilot; no private actions or owner counts. Pending features must say `not implemented`, not fabricate completion.

An AI draft **never** auto-publishes, edits an approved scope, sends a message or incurs paid provider cost without existing gates. One free saved AI note does not claim a provider-generated answer. Invite TTL/revoke and client ACL are preserved. User-facing `new task` means one canonical resource, not a new `ProjectIntake` disguised as project.

## 4. Page anatomy and progressive disclosure

**All top-level screens:** clear H1 *noun* + one-sentence purpose + one primary CTA + short status/next action. First viewport should answer `что это / зачем / что нажать`. Secondary details are optional, with consistent terminology RU/EN/HY/ES and explicit statuses. No opaque learner-demo prose on commercial screens.

**Long pages:** sticky **left in-page rail** at desktop with 3–6 semantic section anchors, keyboard accessible and `aria-label`, using existing White Atlas background/border/teal tokens, Bootstrap Icons and typography; actual content remains center. On tablet/mobile rail becomes compact horizontal local-navigation row (not a second bottom dock). Anchor targets get `scroll-margin-top`. Avoid extra nesting, multiple independent scroll columns, hidden submit buttons and sticky overlays over form controls. Respect `prefers-reduced-motion`.

**Details:** use **Turbo Frames** / Turbo Streams for safe view-only object inspection in an in-page detail region or a right-side sheet; do not globally frame every link. On authorized object selection, update `detail_frame`, maintain a real fallback GET route, restore browser history/back and focus; close via button and Escape, accessible title/dialog semantics, no page jump on expand, and preserve entered form contents. Transition opacity/translate through a namespaced Stimulus controller respecting reduced motion. **Mutations** remain ordinary protected Rails form requests with CSRF, authorization, validation errors and explicit consent; no opportunistic direct provider invocation, destructive action or cross-owner frame leakage. Authentication redirect and file downloads must escape/handle frames correctly.

**Deep route policy:** keep public URL and old route helpers; optionally render same detail partial into frame for authorized GET. Never delete URLs merely to declutter navbar. Navigation should allow both direct bookmarks and back/forward. No dynamic modal for every page; use sheet for short inspection, full page for long interview/spec editing.

## 5. Reversible sequence / tests

- **C2.5a — audit + navigation foundation**: record screenshots and canonical owner map; add first *left* anchored rail to existing long AI assistant page using its current four wayfinder anchors; preserve all routes and actions; CSS only namespaced to that page; responsive fallback existing. No DB or provider changes. Run exact SHA Rails CI/Security Audit and owner 1440/400/320 browser acceptance before calling PASS.
- **C2.5b — Owner surface consolidation**: cabinet retains profile/identity/privacy/spend only; workspace becomes short prioritized queue. Restore clear entry for every moved operational tool in its canonical area *before* removing duplicates. Use existing translations, tests for nav active states, link reachability and roles.
- **C2.5c — Orders entry consolidation**: Requests becomes one list with incoming/outgoing and prominent New request / Invite; existing nested routes preserved; privacy/client auth/expiry tests unchanged. Make client-facing CTA unmistakable.
- **C2.5d — AI consolidation**: conversation is main AI landing, operation picker/drafts/knowledge are subviews; retain paid-call consent, file owner ACL, archive/restore, draft review. Migrate navigation labels only with complete four-locale keys.
- **C2.5e — Calendar vs history IA**: one Calendar area with month/day/consultations, separate human-readable operation history; verify occurrence vs scheduled semantics and source deep-links. No generated false dates.
- **C2.5f — context sheets and sticky rails**: one tested Turbo Frame GET detail (prefer owner-approved safe document or read-only service version), then extend to Requests/Library as supported. Validate mobile focus/esc/back, unauthorized navigation, form error preservation and nested frame redirects.
- **F2–F5**: actual smart quiz, dual spec approvals, project/tasks/delivery only as independently verified verticals, not this UI refactor.

**Acceptance matrix:** owner/verified fictional client/guest; 1440/400/320 px; visible H1 purpose/primary CTA; navbar area is unambiguous; no alternate mutation routes; no unreachable tool; no horizontal overflow; keyboard and reduced motion; browser back / direct URL / Turbo navigation; no AI charge; persisted state unchanged; current pre-existing tests pass on exact SHA. Use separate `CODE_COMMITTED`, `CI_VERIFIED`, `OWNER_BROWSER_ACCEPTED`, `PRODUCTION_DEPLOYED` fields.

## 6. No-go and evidence

Do not alter schema, existing private databases, migrations, storage, payments, budget ledger, existing approved objects, session logic, consent, Active Storage privacy, outbox/replay or production Railway as part of pure IA. The production Railway branch remains older than active Draft PR #81; this audit is NOT deploy consent. A design declaration is NOT implementation. The owner review worktree currently points at old code SHA `aecbe5e`; no remote-only UI commit will appear in its browser until owner explicitly brings a new code revision to a separate reviewed worktree.

**C2.4a browser screen results:** local owner month/day/hour, cabinet, workspace, assistant, notifications, library, consultations, new intake, requests are visually present; 400px guest month/day and 1440-ish owner calendar states seen. Specific 13 Nov 22:37 *hour* and authenticated 320px remain not explicitly screen-confirmed; do not call whole F0 complete.  
**Next owner request:** verify staged **left rail** in AI draft screen at 1440 and mobile fallback at 400, and report screenshots. No payment, production or DB writes.


## 7. Implementation checkpoint — reversible first left-rail slice

**CODE_COMMITTED (not owner browser accepted):**
- `app/views/owner_ai_assistant/show.html.erb`: the existing four section destinations were retained verbatim inside an added two-column `wa-ai-page__screen-grid`, with content wrapped in `wa-ai-page__screen-body`; desktop sticky left wayfinder in scoped `_rc_owner_ai_assistant.scss` at >=1200px, original layout at smaller widths.
- `app/views/owner_setup/cabinet.html.erb`: introduced read-only, accessible in-page links to existing Profile, Tools, Data/Privacy and Work overview sections (all existing translation keys and Bootstrap Icons), adding stable anchor IDs without moving or changing protected forms; scoped `_rc_owner_cabinets.scss` sets left sticky 168px rail >=1200px, flexible inline links on narrower widths.
- **No new JavaScript controllers, translations, Rails controllers/actions, routes, DB objects or migrations.** Responsive acceptance is pending. This code is not in owner's currently running `aecbe5e` checkout.
- The owner's new screenshots and exact running local launch are separately recorded in `docs/RC0551F_C24A_WHITE_ATLAS_COMMERCIAL_UI_BROWSER_FIXES_2026-11-23.md`: C2.4a partial browser evidence, not global acceptance.
- Future slices for top navigation consolidation, reducing duplicate tools, Turbo Frame sheets and source-aware breadcrumbs remain **PLAN_ONLY** until actually tested. Do not assert a seven-tab UI already exists.
