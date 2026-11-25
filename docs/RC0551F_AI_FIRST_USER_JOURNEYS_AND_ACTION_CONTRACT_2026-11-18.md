# Rails Calendar / White Atlas — AI-first user journeys and action contract
**Date:** 2026-11-18  
**Status:** Executable acceptance specification. M1 implemented in Draft PR #81 but not yet owner/live accepted. M2–M8 are planned and **not implemented by this document**.  
**Source of product scope:** RAILS_CALENDAR_AI_FIRST_MVP_NEXT_CHAT_MASTER_2026-11-18, sections 3–9.  
**Current local baseline reported by owner:** `~/rails_calendar_ai_c21c` on `local/rc0551f-c21c`, database `rails_calendar_rc0551f_c21b_review_20261117` (read-only inspection), dependencies and Zeitwerk PASS, `OwnerIntelligence::Grok.enabled? == false`. Port 3001 shows **older C2.1b UI**, not proof of C2.1c execution. No live xAI request yet.

## Product invariant
One continuous workflow: owner AI conversation → approved service → client adaptive request → evidence-based qualification → versioned spec and bilateral acceptance → project/milestones → AI-generated calendar proposal and explicit apply → verified handoff. AI drafts do not equal facts, authorization, approval, completed tests, signed contracts or actual payments.

## M1: First genuinely persisted owner ↔ Grok conversation
**Actor:** authenticated Owner, never Guest/Client.  
**Surface:** `/workspace/assistant/conversations`.  
**Entry condition:** existing Owner account/workspace and approved professional profile; server-side xAI configuration enabled; consent for each paid turn; allocation within existing global `AiSpendLedger`/daily quota.  
**Demo question:** «У меня небольшой Rails-проект. После отправки формы иногда появляется ошибка 422. Составь короткий безопасный план диагностики: что запросить у заказчика, что проверить в logs, CSRF/Turbo и validations. Ничего не считай уже проверенным».  
**Follow-up:** «Теперь клиент уточнил: ошибка возникает только после Turbo-навигации. Пересмотри диагностический план с учётом прошлого сообщения. Не повторяй неизменные шаги».

### Exact operation order
| # | Initiator / operation | Data read / sent | State / expectation | Failure and guard |
|---|---|---|---|---|
| 01 | Owner creates conversation | Owner identity + Workspace | Active conversation, auto default title, zero provider cost | Tenant authorization |
| 02 | Owner enters question and presses "Ask AI" | Body <=1200 characters, UUID, `intent=ai` | Form has two distinct actions: free note vs paid AI turn | Invalid input preserves unsent text and UUID |
| 03 | Rails checks Owner, thread, state and paid consent | Authenticated Owner workspace; `paid_consent=1` | NO paid call without explicit per-turn consent | 422 keeps typed text for correction; never submit to xAI |
| 04 | Rails checks provider enabled | `RC_GROK_ENABLED`, valid `XAI_API_KEY` in process | AI button only active when configured | Disabled configuration returns visible error, no paid attempt |
| 05 | Rails locks conversation and writes pending pair | One Owner question + one Assistant placeholder, sequence, UUID and parent | Duplicate request UUID cannot create another billable turn | Archive rejected; active pending/uncertain turn blocks another paid request |
| 06 | Rails assembles bounded safe context | Max 10 preceding **settled paid** turns plus current question; at most explicit approved public headline/summary | No private notes, client records, attachments, credentials or unpublished facts automatically sent | Context payload over limit rejected |
| 07 | Rails allocates spend | Existing profile, `owner_ai_chat_v1`, model, fingerprint | `AiSpendLedger` reserves USD $0.10 allowance; this is NOT a price quote | Quota and budget gate; no second ledger |
| 08 | Rails sends one Grok Responses API call | System instructions + bounded JSON payload, `store:false`, `tools:[]`, strict JSON schema | `title`, `answer`, `suggested_actions`; **title generated in same billable request** | No browsing, tools, autonomous external actions |
| 09 | Rails validates answer and provider usage | Schema, lengths, `usage.cost_in_usd_ticks` | Ledger `settled`; model answer saved as `settled`, Owner question `settled` | Any ambiguous provider outcome → `uncertain`, no automatic retry |
| 10 | Rails updates title | Model title only when first paid turn and title is provisional | Manual rename remains authoritative | Archive remains read-only |
| 11 | Rails shows answer and receipt | Escaped HTML, suggestions, timestamps, actual provider-reported cost | Refresh and navigation preserve real history | No fictional success for pending/failed/uncertain |
| 12 | Owner sends follow-up | Previous settled messages + new question, fresh consent and UUID | AI incorporates earlier diagnosis, no fabricated logs/observations | Duplicate submission cannot double charge |

### M1 definition of done
- **M1-A:** Owner new chat works without manually entering title; first result gives useful answer and auto title.
- **M1-B:** Two consented live turns with correct bounded context and **two genuine xAI ledger entries**, reload persists text and title.
- **M1-C:** Manual rename survives subsequent calls; archive is read-only; no foreign tenant read/write.
- **M1-D:** On missing consent/disabled provider, text/UUID remain visible; no new spend.
- **M1-E:** For provider 429/timeout/ambiguous billing, show uncertain and block automatic replay.
- **M1-F:** Desktop 1440, mobile 390/320 and keyboard navigation; White Atlas style intact.
- **M1-G:** Ruby CI, JS security audit and manual owner acceptance are separate gates; *mock HTTP CI is not live provider proof*.

### Required isolated run preflight
1. Compare exact branch SHA after fetching, inspect local worktree cleanliness.
2. Confirm intended DB name and role on the *new server* before changing any records. **Do not share same development DB for writable concurrent old+new servers**, without explicit approval and a reviewed isolation plan. Existing 3001 is old C2.1b UI.
3. Confirm Rails process Grok enabled state without ever printing API key.
4. First verify UI with GET/read-only, then **request explicit approval** for a pilot paid call and any local test-data mutation.
5. Never run `db:prepare`, `db:reset`, `db:schema:load`, `db:migrate`, or reset production/Railway under this test protocol.

## M2: Contextual AI actions by screen (future)
Common pipeline: server resolves principal/role/object/version → builds allowlisted context → cost/consent → strict action-specific AI schema → validates answer → shows **preview/diff** → user explicitly applies to an editable draft → audit with source/version/author. The AI must NOT execute a page action just because chat text suggests it.

| Surface | AI action | Sources / output | Human-confirmed effect |
|---|---|---|---|
| Owner chat | answer, follow-up, summary, route to action | approved facts + dialogue; structured answer | Owner chooses any follow-up action |
| Owner cabinet / practice | refine professional presentation and suggest skills/services | approved self-assessment, capability restrictions | Owner reviews what is public |
| Owner services | improve copy, exclusion policy, FAQ, intake quiz | exact owned `ServiceOfferingVersion` + digest | Apply to **draft** only; publish is separate |
| Client request form | ask only one missing relevant question at a time | selected **published** service, previous answers | Client selects, edits and submits |
| Client request detail | summarize missing requirements, explain spec | only customer's own request and visible spec | Client confirms answers/scope |
| Owner inbox / scope | classify fit, risks, missing facts, generate spec draft | assigned intake and selected approved service | Owner edits and approves spec |
| Project tasks | propose breakdown, test ideas, milestone order | accepted scope version and authorized project | Owner confirms tasks |
| Calendar | parse time intent, propose/reschedule, detect conflicts | owner's permitted events, timezone, availability | Owner confirms specific event changes |
| Project files | extract and classify selected content | explicitly consented allowlisted assets | Owner authorizes AI transfer and handoff |

## M3: Live calendar and AI time planning (future)
- **M3.1 no model cost:** time axis distinguishes past/current/future on day/hour/month; past empty slots dim, actual completed/past *content remains readable*. Today line `Now HH:MM`; no duplicate Turbo timers; timezone-aware and accessible at 320/390/1440. Passed time != completed task.
- **M3.2 one specific text-to-time scenario:** «В следующий рабочий день: Rails bugfix 10:00–11:30, тесты 12:00–12:45, ответ клиенту 16:00–16:30. Покажи черновик и конфликты, не сохраняй до подтверждения».
- AI proposes `title/kind/source_ref/date/starts_at/ends_at/timezone/priority/status/confidence/assumptions/conflicts/requires_approval/source_version`; Rails enforces authorization, valid intervals, overlap, timezone and stale-version locking.
- Owner sees **three proposed slots** and can edit one; only explicit apply writes confirmed events once, with provenance and undo by version. Never claim AI proposal is already booked.

## M4: Smart client intake (future)
- Client selects a **published** service such as Rails bugfix, CRUD/forms, API integration, landing page, redesign, or other. Defaults to existing published services, not fictional catalogue entries.
- 3–6 compact steps: symptom category → where/when occurs → steps to reproduce → already known evidence → budget/urgency only when needed → summary.
- AI picks the *next missing* structured question and allowed answer options. `I don't know`, `Other`, multi/single select, back/edit and manual input always supported.
- Client prompt: «Ошибка 500 при оформлении заказа, иногда, причину не знаю». AI must ask about environment/logs/reproduction but **never** request secrets.
- Version answers with provenance; deterministic fallback if Grok disabled or quota exhausted.

## M5: Qualification and bilateral spec (future)
- Server enforces hard no-go, rights and service scope; AI may propose fit/risks/missing facts.
- Build editable versioned spec from *confirmed* input, marked AI assumptions, exclusions, acceptance criteria and dependencies.
- Owner edits/approves a specific version; Client sees only published version and may request changes or accept scope. Read receipt != acceptance.
- Model never automatically confirms price, deadline, payment or contract.

## M6: Project plan, milestones, tasks (future)
- Require accepted scope version before project creation.
- AI decomposes accepted scope → proposed tasks and dependencies → proposed milestone order → available time slots.
- Owner approves tasks and schedule. Project and Calendar read the same approved source refs/versions, not drifting copies.
- States proposed/confirmed/in_progress/completed/cancelled and clear distinction overdue versus past date.

## M7: File analysis and verifiable handoff (future)
- Private versioned files with explicit per-asset AI consent, MIME/size limits, auth and scanning/extraction strategy.
- AI extracts permitted facts, proposes test cases/checklists/release notes; Rails tracks actual test evidence separately.
- User approves exports/handoff. Never claim an unexecuted test passed or an unpaid invoice was paid.

## M8: Quality, notification, release (future)
- Notify only on real persisted events and approved changes. Observability and retry/reconciliation policy; tenant, CSRF, prompt-injection, budgets, privacy.
- Ruby/browser audit and JS dependency security gate at exact HEAD; 1440/768/390/320 manual acceptance.
- No production/Railway, external messages, migrations on original DB or real customer data until explicit release gate.

## Status vocabulary / next test handoff
`implemented` ≠ `CI passed` ≠ `local GET validated` ≠ `live provider validated` ≠ `owner accepted` ≠ `released`.  
**Immediate next user actions:** verify updated branch SHA, launch read-only AI UI on separate port with existing server untouched, send screenshot and non-sensitive runtime Grok readiness check. If access to data writes is necessary, establish explicit scratch DB isolation before interaction.  
**Unresolved separate release blocker:** JS Security Audit on `picomatch` transitive dependency; do not waive.
