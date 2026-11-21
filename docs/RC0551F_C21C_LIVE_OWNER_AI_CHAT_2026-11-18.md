# RC055.1f — C2.1c consented owner AI conversations (2026-11-18)

## Why
PR #80/previous stacked drafts persist private Owner notes but do not produce an AI answer.
This slice adds the first actual xAI Responses API turn in the **same** conversation
without changing migrations, existing data, paid draft composer, ownership model or Railway.

## Scope and implementation
- `OwnerAiConversationsController`: two distinct submit intents: free saved note versus
  one explicitly consented paid AI call, with owner/tenant lookup, UUID deduplication,
  conversation lock and pending turn records. A pending/uncertain previous AI call
  prevents a new billed turn in the same thread.
- `OwnerAi::ConversationResponder`: reuses xAI Responses API model/endpoint and the
  existing `AiSpendLedger.reserve!/settle!/uncertain!`, global quota and pilot caps.
  Strict JSON `title`/`answer`/`suggested_actions` with bounded input/output,
  no provider tools, `store:false`, no arbitrary URL fetching or execution.
- Context is limited to ten **settled paid dialogue messages** plus the current
  question and only owner-approved, publicly shareable profile headline/summary.
  Free notes, private fields, attachments, customer records and account secrets
  are not sent automatically.
- Model title is generated in **the same** billable call, only for the first paid
  turn when the title is still the initial prompt-derived provisional title.
  A manually renamed title is not auto-replaced. Archive is read-only for new turns.
- Pending/failed/uncertain assistant records are never rendered as invented answers.
  Settled answers and provider-reported charged USD ticks are shown separately.
- RU/EN/HY/ES labels preserve the established White Atlas layout without a second theme.

## Accounting and failures
- Per-call ledger reservation is USD 0.10 at current existing settings, **not an
  asserted final provider price**. Provider usage `cost_in_usd_ticks` is recorded.
- Missing consent / disabled provider cannot send a request.
- Disabled quota or budget leaves a failed synthetic placeholder, no AI answer.
- Timeout / HTTP error / malformed structure after request reservation is
  `uncertain`; no automatic retry. An uncertain record blocks subsequent AI
  requests in this thread until manually reconciled.
- Multiple submissions of one form UUID cannot generate two billable calls.
- The conversation and spend ledger remain private to their Owner workspace.

## Gates and evidence
- Source branch: `feat/rc0551f-c21c-live-owner-ai-chat-2026-11-18`
- Base: PR #80 HEAD `159b29c28e66a8a4158a62d144b3dd7126519ab4`
- PR: https://github.com/TheGor-365/rails_calendar/pull/81 (Draft)
- Mock integration tests cover consent, two-turn context, title, private-data exclusion,
  idempotency, XSS, timeout and budget/IDOR/archival, but **mock tests do not prove live AI**.
- No actual provider expense, migrations, local DB commands, merge or Railway deployment
  were authorized or performed by this change.
- External owner acceptance remains open: local `git status -sb`/HEAD identity,
  safely checking out the stacked branch, CSS/build, one explicitly approved paid
  Grok call, follow-up, reload, actual ledger entries, desktop 1440/mobile 390/320.
- Security release gate remains open until parent JavaScript dependency audit is
  resolved. Log on exact PR #81 CI showed `sass > @parcel/watcher > picomatch`
  high-severity ReDoS advisory; the audit tool reported no patch at that moment.
  Do not bypass the audit or call the release clean without fixing/verifying it.

## Manual acceptance examples
1. Ask: «У меня небольшой Rails-проект. После отправки формы иногда ошибка 422.
   Дай безопасный план диагностики логов, CSRF/Turbo и validations. Не выдумывай причину».
   Expected: a **real** saved Grok answer, sensible title, one real billed ledger entry.
2. Follow up: «Это происходит только после Turbo-навигации. Уточни предыдущий план».
   Expected: bounded prior history is used, a second separately consented turn, no
   duplicated billing from a repeated form submission.
3. Rename, reload, archive; verify the manual title persists and the archive cannot
   accept more calls; test slow provider or offline with mocks only.

Do not mark accepted, deployed, production-ready or safe for client data before the
specific gates above are completed and the owner explicitly signs off.
