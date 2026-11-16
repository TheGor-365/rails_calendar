# RC055.1f Slice A — Owner AI actions / White Atlas floating launcher
**Date:** 2026-11-16 · **Status:** implemented in stacked Draft PR #71, awaiting exact-HEAD CI + local owner visual acceptance. **Base:** RC055.1e Draft PR #70 (f7fd3fc). No production deploy/merge/migration.

## Owner decision and purpose
AI must do substantially more than audit: generate useful service copy, intake forms/questions, client reply drafts, project outline documents, with custom user task. A role-aware floating assistant must be visible throughout the owner workspace. Client assistant, cross-file analysis, two-sided intake, negotiation/contract and calendar execution are in RC055.2–RC059; do not start with unrestricted model tools.

## Implemented Slice A
- Typed, immutable owner operation registry: `service_copy`, `intake_questions`, `client_reply`, `plan_outline` with bounded system instructions and max token output.
- A free-form 12–1200-char brief, explicit consent for exactly one billable Grok request, existing `OwnerIntelligence::Grok` (xAI Responses structured JSON), `AiSpendLedger` and `IntakeAiQuota` budget, idempotency and uncertain-billing handling.
- Only approved **public-facing owner professional profile facts** automatically supplied (headline, public_summary), plus the owner's own typed brief. No full interview, private owner profile, client data, files, or key disclosure automatically. No arbitrary tool calling.
- Validated structured result with heading, draft, questions, cautions and next step, stored as private `AiSpendEntry` only. GET is read-only; model outputs escaped in ERB. No send, publish, apply, contract, file upload or payment.
- `/workspace/assistant` owner-only review screen and `/workspace/assistant/drafts` consented POST; a global owner-only floating `<details>` launcher with operation selector, task text, explicit billing checkbox and navigation. Enhanced via tiny Stimulus controller for Escape/outside-click and Turbo cache; native no-JS fallback.
- Scope styles in `_rc_owner_ai_assistant.scss` using existing `--ws-*` tokens, `surface-panel`, `rc-action`, `ws-owner-hero`, `rc-input`, scoped White Atlas typography; original calendar and cabinet untouched. RU/EN/HY/ES.
- Automated HTTP tests cover owner/client/foreign owner, no-cost GET, rejected op/no-consent POST, stored-result IDOR and XSS escaping, schema strictness. Chrome browser test covers launcher, Escape and 390/320px overflow.

## Critical limitations and next slices
- This is a **draft generator**, not the final dialog-based copilot. It redirects to a protected review screen; persistent chat, true modal response, role-sensitive command router, live navigation parser, typed apply/undo service and per-service versioned edits remain RC055.1f follow-on slices.
- No RAG/attached files, document extraction, autonomous access to other services, knowledge interviewer, AI pricing promise or public client conversation. Add private scanning + per-asset consent before any external file processing.
- Do not change xAI API key endpoint permissions without adapter need and least-privilege review.
- Never assume a floating button means Grok is configured. Server rejects disabled calls.
- No new DB migrations. Existing ledger records generated output; payment cap and separate approval remain mandatory.

## Test and release acceptance gates
1. Exact PR #71 HEAD Rails tests, Chrome tests and Security Audit green; no paid API calls in CI.
2. Owner review local build from clean branch; desktop 1440/1280; mobile 430/390/320: no horizontal scrollbar, visible read-only draft and native form controls, accessible focus, Escape/outside click and Turbo restore.
3. Owner manually checks paid consent and explicit data disclosure, but **does not need to run a paid request** solely for UI QA; fake provider fixture verifies format and ACL.
4. New owner-approved screenshot before closing UI slice. Keep all PRs Draft. Main/Railway unchanged. Production release requires full ancestry gates, private file backup+restore, privacy, RBAC, identity and explicit owner authorization.
