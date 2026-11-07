# RC-027 — AI client intake, reviewable spec and suggested milestones

**Date:** 2026-11-08. **Parent:** RC-026 [Draft PR #26](https://github.com/TheGor-365/rails_calendar/pull/26). **Status:** Draft implementation; do not merge or publish real client data until explicitly approved.

## User value

A synthetic client describes a website (or Rails bugfix/API integration), answers at most eight clarification questions, and gets a versioned draft specification after **administrator review**. The draft includes goals, deliverables, acceptance checks, uncertainties, explicit exclusions and *proposed* milestone durations. An authorized owner may approve the exact version for demo-client review; the demo-client may acknowledge it. That is not signed consent or a commercial agreement.

## API integration

- Production calls are **off by default**. To opt in, both \`RC_GROK_ENABLED=true\` and a separately stored server secret \`XAI_API_KEY\` must be present. Never put the secret in the repository, screenshots, ChatGPT chat, Notion or Drive.
- Uses xAI **Responses API** at \`https://api.x.ai/v1/responses\` with \`model=grok-4.3\`, \`store=false\`, no tools and strict JSON schema. The existing Railway budget is separate from xAI API credits.
- The database-backed cap is **12 attempted AI calls per UTC day per app**. The user interview caps at eight submitted answers per intake. Short timeouts and no retries prevent accidental large costs. If missing API key, quota exhausted, or API unavailable, a clearly labeled local demonstration template replaces the AI output.
- xAI's new Responses API is preferred to legacy Chat Completions for new development. Structured JSON is validated and escaped when rendered; model text cannot perform server actions or accept scope/fees.

## Security and data

- The synthetic-demo creation flag \`RC_INTAKE_PUBLIC_DEMO\` defaults off, so anonymous users cannot create submissions. Authenticated administrator can create synthetic demos.
- Each demo intake is accessible only to administrator or the **same browser session** that created it while the demo flag remains enabled. This is NOT a durable customer account; user identity, multi-device invite, tenant ACL, verified approval evidence, retention and consent/legal terms still need to be implemented before accepting genuine client work.
- The form requires explicit acknowledgement to use **fictional data only**, with notice that data may be sent to xAI if enabled. No email, payment, password or identity fields. Sensitive goal/body/document parameters are filtered from Rails request logs.
- New tables are independent of \`consultations\` and have no delete callbacks in the web controllers. Project planning is shown as *proposed phases*, not booked calendar slots.

## In-scope screens and actions

1. Public synthetic-gated or admin form: \`GET /project_intakes/new\`, \`POST /project_intakes\`.
2. Same-browser, admin-or-client-protected interview: \`GET /project_intakes/:id\`, \`POST /project_intakes/:id/reply\`.
3. Admin inbox \`/admin/project_intakes\`, admin-only \`draft_spec\` and \`approve_spec\`.
4. Demo client acknowledges an admin-approved version through \`acknowledge\`. Versioned record is kept; no payment, email or actual delivery date is generated.

## Not done / remaining work

**Not yet implemented:** user accounts/client-per-record identity, cross-device secure invitation, public anti-spam CAPTCHA/rate-limit, client privacy/export/delete policy, reviewer edit-and-approve of AI output, real signed scope approvals, timeline date assignments, calendar events, task completion, notifications, document exports or live customer transactions. Never market these as completed. No automatic project creation from an AI answer.

**Release gates:** exact SHA CI+Security, isolated migration forward/rollback on synthetic DB, owner-approved staging, verified TLS proxy+CSRF cookie and budgets. All existing owner consultations #3/#4 and local \`ruby_calendar\` must remain unchanged. New Grok API key, if needed, must be created on xAI dashboard with **text/Responses-only scope**, small RPM and bounded expiry and set only in Railway secret manager. API calls are billable separately from Railway.

References: [xAI API pricing](https://docs.x.ai/developers/pricing), [xAI structured outputs](https://docs.x.ai/developers/model-capabilities/text/structured-outputs), [xAI Responses API](https://docs.x.ai/developers/rest-api-reference/inference/responses).
