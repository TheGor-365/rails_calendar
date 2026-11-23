# RC051 — Paid Grok 4.3 pilot and accounting (2026-11-13)

## Release boundary
- Base: production parity SHA `90d7a817651ba1bffe174d3f800d32988a664169`.
- Draft PR only. **No automatic production activation.** Railway currently has no verified restore/backup; do not deploy this migration until review.
- Actual calls use `https://api.x.ai/v1/responses`, `grok-4.3`, `store: false`, `tools: []`, structured JSON schema.
- The same paid provider code is the release implementation. Unit tests stub only external HTTP so they cannot spend money.
- Manual backup: existing template fallback, owner edits producing a new immutable human specification version. AI never approves scope or executes supplied code.

## Accounting rules
- Unit: integer USD ticks (1 USD = 10^10 ticks); bill each successful request using `usage.cost_in_usd_ticks` **from xAI**.
- Development pilot budget: $2 total across attempts in this database, $0.50/day, $0.50/intake, reserve $0.10 per network attempt; existing cap 12 attempted calls/day remains.
- PostgreSQL advisory transaction lock serializes *new* reservations across app workers, and a unique request digest prevents duplicate paid network calls for identical input.
- A settled result is replayed from the database without a new provider call. A network timeout, invalid JSON, non-200 response or missing provider cost is marked `uncertain`; full reservation is held and the same request cannot be retried without a separately audited repair.
- Limitation: an individual provider charge can exceed the reserved 10 cents. Its full amount is still recorded and future calls blocked. This is an **application budget guard, not an absolute xAI account billing limit**; maintain prepaid credits and review the provider console.
- No API key, raw request payload or credential is logged or committed. The resulting approved synthetic document and limited usage counters are persisted.

## One-time local preparation
1. Keep the validated system PostgreSQL preview URL from `~/.config/rails-calendar/preview-3012.env` and `calendar-ai.dev.env` outside git.
2. Pull this branch into a **clean** local working tree. Do not change existing QA worktrees.
3. Source only the preview env file; verify `RAILS_ENV=development`, Unix socket, database name `rails_calendar_mvp_preview_20261112`, role `gor`, one owner, one client and Booking API intake ID 1.
4. Run only `bin/rails db:migrate:up VERSION=20261113213000` on that verified local database.
5. Run focused tests and full Rails/Chrome/security CI before using the API.
6. Source the separately stored API key and set `RC_GROK_ENABLED=true` **only on a local process**. A first owner-only synthetic draft should consume one small real request, write the entry, then show Grok-source spec in owner UI after reload.
7. Inspect `AiSpendLedger.spend_summary` and xAI Usage; exercise manual revision and owner approval before showing the client the exact approved version.
8. For production paid use, a separate protected secret and `RC_GROK_PRODUCTION_APPROVED=true` are required **after** privacy/access review. Public client enrollment and local-only client request pilot are not activated by this change.

## Failure/rollback policy
- Do not delete ledger rows after ambiguous timeouts. Reconcile with provider Usage and record a separate audited decision before retrying a changed input.
- Do not blindly run `db:rollback` on production, and do not equate code rollback with restoring DB data.
- Missing secret, quota exhaustion, exhausted budget and unavailable provider leave owner free to edit or use a template without calls.
- Release success means: real Grok response, nonzero xAI cost in ledger and console, owner human revision/approval, exact published spec on client, security tests passing.
