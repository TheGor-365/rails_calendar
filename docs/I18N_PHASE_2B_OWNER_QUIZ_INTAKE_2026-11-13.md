# i18n Phase 2b — Owner Workspace, Offline Quiz, Intake and Specs

2026-11-13. Stacked Draft PR on i18n Phase 2a PR #47.
No production deployment, main merge, DB migration, paid xAI API, key, or email delivery changes.

## Architectural invariant
- Translates 4 locale YAML modules: workspace, quiz, intake. English canonical.
- UI strings include owner dashboard and counts; offline synthetic Quiz questions, option labels, forms, four actions, persisted answer snapshots and review; localized Stimulus dirty-state/unsaved navigation warnings; intake creation/type and status labels; workflow; private interview; spec review sections; proposed milestones; administrative inbox/edit form; success and validation notices.
- QuizCatalog OUTCOMES and FEATURES are still **canonical English-key maps**. Only their presentation uses `rc_quiz_question_title` and `rc_quiz_option_label`. Keys (e.g. `website`, `outcome`, `contact_form`) still travel through controller and remain in database and revision snapshots as before.
- Project Intake type/status enums and spec JSON section keys unchanged. Stored conversation, customer-entered text and all prior AI/template-generated spec bodies are not silently translated or overwritten. Existing English synthetic interview questions remain in previously recorded messages.
- Owner role + legacy admin guards, CSRF/secret configuration, API-disabled state, UTC, files, timers, history, and moderation are unchanged. Language cookie never grants access.
- HTTP `/workspace`, `/project_intakes`, quiz and admin pages stay private; no live real-client intake. The existing Grok adapter remains gated by RC_GROK_ENABLED and XAI_API_KEY, neither enabled/used by this PR.

## Required QA
- Full Rails, Chrome, Security Audit on exact HEAD; four-language integration tests proving canonical option values, revision invariance and owner-only access.
- Local 320,390,430,1280 mobile + keyboard, two questions saved/edited/back/review with synthetic fixture; admin spec draft and human edit/approval, tentative project calendar.
- Check real local account DB identity before login; see user's :3012 isolated preview database vs historical :3015 DB.
- Do not interpret mocked/offline provider fallback as actual Grok operation.

## Real AI pilot prerequisites
Isolated owner-only synthetic intake, per-call idempotency, persistent reservation/ledger + daily budget, strict output schema, redaction/no PII, 429/timeout retry policy, exact model and costs, approvals for provider egress and paid test. PR #41 is an **independent Rails test-only mock contract**, not a live caller; it must not be merged blindly with this stacked branch.

## Release
Production remains RC-035. Main remains behind RC-035. PR40 public services code-only is first deployment candidate after backup/restore, browser QA, external CTA receipt and explicit go. Full stacked PR44/45/46/47/48 must NOT be deployed wholesale; PR44 has an additive DB migration. 
