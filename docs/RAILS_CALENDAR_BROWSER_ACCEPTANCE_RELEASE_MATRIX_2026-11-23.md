# Rails Calendar — browser acceptance and release decisions (no backup owner choice)

**2026-11-23 | Code source: Draft PR #81, owner browser; deployment: old Railway SHA `90d7a817`.**

## Rule of evidence

- Status for each feature: `CODE_PRESENT`, `CI_VERIFIED`, `MANUAL_BROWSER_PASS`, `MANUAL_BROWSER_DEFECT`, `PRODUCTION_LIVE_PASS`, `PRODUCTION_NOT_DEPLOYED`, `PROVIDER_REAL_VERIFIED`, `NOT_TESTED`. A route, green CI or a browser tab snapshot is NOT live feature signoff.
- Human checks: owner signs in locally on 127.0.0.1:3002 (if running); use **fictional data only**. Do not paste cookies, CSRF hidden inputs, API keys, auth URLs with invitation token, client IDs, user emails or personal contents into chats/GitHub. Screenshot cropping/redaction before sharing.
- For **each page**, run desktop 1440px, mobile 390px, small mobile 320px where relevant. Check no horizontal scroll, one complete action, persistence after browser reload, no accidental AI billing, navigation back and privacy with guest/client. Record exact page URL path (without IDs/tokens), role, result and screenshot proof.
- Never upload files to production or create real client requests during *baseline* checks. Buttons marked `publish`, `approve`, `delete`, `send`, `revoke`, `pay`, `ask AI`, `restore` may write or bill; use **local disposable test data only** and only after checking DB identity. The first round is GET/read-only in both environments.
- User explicitly reports **no production backups** and requests proceeding without them. **Risk acknowledged, not mitigated**: production PostgreSQL data and local web files could become irrecoverable; code rollback cannot undo a schema migration or restore deleted records. This is NOT blanket permission for any particular production write, migration or paid action. Per-release explicit SHA + single migration + acceptance and risk signoff are still required. Keep incremental updates additive and AI default-off. A deploy that runs `bin/rails db:migrate` can mutate the real DB.
- Existing production web lacks persistent Active Storage volume. Do not deploy new avatar/media features until durable storage is resolved or an owner-approved, loss-aware alternative exists. This matters even with no backup.

## A. First pass — READ-ONLY browser inventory (one page at a time)

| Batch | Role | Local path | What to observe, no write | Current browser acceptance | Release disposition |
|---|---|---|---|---|---|
| A0 | owner | `/workspace` | menu, account, owner-only boundary, mobile | NOT_TESTED | baseline |
| A1 | owner | `/workspace/assistant/conversations` | list/empty state, New Chat, composer, paid consent/UI disabled label | NOT_TESTED | F1 priority |
| A2 | owner | `/workspace/assistant` | AI Studio, knowledge, four suggested actions, private launcher, spend explanation | NOT_TESTED | F1/F3 |
| A3 | owner | `/workspace/services` | existing drafts, approval vs enable separation, card layout | NOT_TESTED | F2 |
| A4 | owner | `/workspace/services/ai` | Copilot, no request without explicit consent | NOT_TESTED | F3 |
| A5 | owner | `/workspace/setup` and `/workspace/practice` | profile/work policies, approved vs draft state | NOT_TESTED | F2/F3 |
| A6 | owner | `/workspace/notifications`, `/workspace/activity` | unread, events, no read mutation on GET, no PII in export | NOT_TESTED | F2 |
| A7 | owner | `/workspace/invitations` | create invitation form, TTL, no accidental issued token | NOT_TESTED | F2 |
| A8 | owner | `/workspace/library` | artifact list, private download rules, no dead buttons | NOT_TESTED | F4 |
| A9 | owner | `/workspace/outbox/health` | disabled replay, NO executable replay controls | NOT_TESTED | operations only |
| A10 | owner | `/admin/project_intakes` | owner intake inbox, no real-client mutation | NOT_TESTED | F2/F4 |
| A11 | owner | `/consultations` and `/` | calendar, consultation list and responsive day/hour | NOT_TESTED | R1 |
| A12 | public | `/services` | public catalogue without private owner details | NOT_TESTED | R1 |
| A13 | guest | `/register`, `/sign_in` | proper login/OTP UI; no submitting real PII | NOT_TESTED | R1 |
| A14 | client | `/client/cabinet`, `/client/requests/new` | verified client vs guest restrictions, form visibility | NOT_TESTED | F2 |

## B. Writable local synthetic browser scenarios (after safe isolated DB target verified)

1. **B1 Owner chat:** Create an empty conversation → save one ordinary synthetic *note* using **Save message** (not Ask AI) → reload and confirm exact message persists → archive/restore on synthetic conversation → guest/client forbidden. No paid provider. Automation: `test/system/owner_ai_conversations_browser_test.rb` uses isolated CI test DB only; its result requires exact SHA CI.
2. **B2 AI Studio:** open 4 action cards `service_copy`, `intake_questions`, `client_reply`, `plan_outline`; confirm fixed scope, correct source, fake/mock response and explicit owner apply/reject. No xAI secret or automatic invocation. Use existing system tests plus manual controls.
3. **B3 Real AI (SEPARATE CONSENT):** after B1/B2, one named fictional input, one clearly approved xAI paid call, budget cap and confirmed result vs provider billing. Verify persisted reply/cost and no retried uncertain response. Real AI not claimed working until then.
4. **B4 Services:** create one fictional service → edit draft → finalise → explicitly enable → check public vs internal visibility; versioned changes preserve past publication. Test media without writing to production.
5. **B5 Client invitation:** owner creates ONE fictional 48-hour invitation → anonymous opens token in browser fragment (never paste URL/token) → registered verified test client claims once → guest sees no private goal, unrelated client cannot claim.
6. **B6 Client request:** 12-section form → autosave → reload → submit once → owner inbox/unread → reply → client reload → owner review/spec. Distinct owner/client browsers or private windows.
7. **B7 Spec:** review exact version and source evidence; owner vs client approval must not masquerade as legal signature; export and restore view.
8. **B8 Calendar:** create synthetic consultation → validate duplicate/stale edit, UTC day/hour, mobile 320/390.
9. **B9 Security:** guest/client blocked from owner AI, services drafts, library, outbox, private media; do not inspect private data in logs/screenshots.

## C. Production baseline first — strictly READ ONLY

- Connected browser previously had an owner-session `/workspace` at `https://rails-calendar-ai-web-production.up.railway.app/workspace` and a local `/` tab at `http://localhost:3002/`; this is *tab snapshot evidence*, NOT a fresh live HTTP test or feature proof. No cookies, hidden tokens or personal account details copied here.
- Open live production `/workspace`, `/consultations`, `/services` manually. Confirm content after full reload and status at 1440 + 390. Do not create sample data on production before explicit release signoff.
- Production currently deploys SHA `90d7a817` from 13 Nov. RC051 R1A candidate on Draft PR #82 SHA `558cf80` already has **6/6 CI successful** and one additive `ai_spend_entries` migration. This is migration rehearsal and code quality, not production browser acceptance or real provider billing.

## D. Feature release train without pretending backups exist

| Release | Candidate boundary | Required proof | Status |
|---|---|---|---|
| R1A | RC051 AiSpendLedger/Grok intake, 1 migration | owner manual UI + no paid call by default + exact CI 6/6 + explicitly accepted no-backup risk | PREPARED, NOT_DEPLOYED |
| R1B | RC052/RC053 owner setup & intelligence | local synthetic happy/negative browser + isolated PG18 migration on deployed base + role controls | NOT_READY |
| R1C | White Atlas owner/client navigation, requests, notifications | desktop/mobile, existing records persist, one synthetic invitation/client | NOT_READY |
| R2 | Services, approved copy, AI Studio | versioned human approval, abuse/tenant checks, durable media decision | NOT_READY |
| R3 | Real owner AI Chat and scoped E1/E2 client funnel | stable chat, explicit one paid AI smoke, privacy, migrations, durable files | NOT_READY |
| R4 | Specs/projects/delivery | approved versioned proposal and cross-role acceptance | NOT_READY |

**Exit checklist for each release:** exact SHA; CI/Security PASS; browser owner+guest+client evidence; schema delta and migration list; data safety of existing records; pinned feature flags/provider OFF unless explicitly allowed; no-backup business risk explicitly confirmed for that SHA; named Railway service; deployment log/smoke; rollback constraints and follow-up result stored in GitHub. No bulk merge of stacked PR #81.

## E. Immediate steps

1. Open `http://localhost:3002/workspace/assistant/conversations` in the existing local owner session. Screenshot the full UI with any sensitive identifiers redacted. No Ask AI, no file uploads, no new notes yet.
2. Report whether `#owner-ai-conversations`, new-thread action, message composer, consent notice and responsive layout appear. If local server is down, return the exact browser error, no DB/migration commands.
3. Based on screenshot, mark `A1 MANUAL_BROWSER_PASS` or `DEFECT` in canonical status and move to B1 free-note retention test. Then A2 and A3; each successful feature informs release selection. Current production stays unchanged until R1A release signoff.

## 2026-11-23 owner screenshot QA and C2.4a retest

Owner and fictional client render at local 3002. Calendar mobile 400px cluttered, past-month grid faint; owner activities around 22:37 present in month but not visible as typed cards in hour; redundant bottom dock Sign out and native + custom disclosure arrows; noncommercial demo boilerplate. **C2.4a source prepared** (scoped styles, views, i18n, tests) in feature PR #81. **NO new browser verification or production deployment yet.** Retest 1440/400/320, 2026-11-13 22h, owner/client header sign-out, one-chevron accordions. Paid AI and recorded review DB writes are not part of this UI retest.
