# Grok/xAI Pilot — stage-zero mock contract (12.11.2026)

**Status:** MOCK ONLY. Code is in an isolated Draft PR stacked on RC-039, **not in production**. No paid API calls or real customer content.

## Scope completed in this PR
- `Studio::AiProviders::XaiGrokMockContract` verifies a simulated xAI Responses API envelope with model `grok-4.7`, structured JSON, source IDs, recommendation/unknown fields and mandatory `needs_human_review`.
- Rejects missing/invalid `usage.cost_in_usd_ticks`, oversized tokens/costs, extra fields, forged acceptance, mismatched source identifiers and revoked owner access.
- Runs ONLY in Rails test, against fictional owner/workspace/project fixtures. The injected response adapter is not an HTTP client.
- No `XAI_API_KEY`, no real token usage, no provider requests, no mutations, no new migrations and no integration into `Studio::OfflineAiDispatcher` (the existing paid-provider prohibition remains intact).

## Limits, classification and truth labels
- Model for future research: `grok-4.7` (see official xAI docs).
- Token caps exercised in mocks: input 1200, output 400; simulated provider cost ≤100,000,000 ticks ($0.01).
- Returned `reported_mock_cost_ticks` is a fabricated test fixture and must **never** be treated as real expenditure.
- `billed_usd_ticks` = 0 and `provider_executed` = `mock_only`. Status: `AI_OFF / MOCK_CONTRACT_PASS` only if exact-HEAD tests pass.

## Unmet gates before enabling any live xAI call
1. Verified owner xAI account, allowed model, billing and a personally approved maximum budget, proposed $1 for one-off smoke.
2. Separate, reviewed **persistent** request reservation and cost ledger (per-call/day/month limits, idempotent concurrency, usage ticks, token caps, error/timeout reconciliation). The in-memory mock is NOT a ledger.
3. Server-only provider transport, strict JSON Schema, verified xAI SDK/API version, timeouts, 401/429/5xx failure handling; no raw prompts in logs. Responses must fail closed when costs are absent.
4. Separate consent/privacy and source classification gate; only synthetic inputs in test/staging first. Owner-only via authenticated Rails session, tenant ACL per request, immediate revocation.
5. Tests: invalid responses, injection, IDOR, 429/503, timeout, concurrency, budget caps, sanitization, rollback and successful nonproduction end-to-end. Never enable `RC_GROK_ENABLED` automatically.
6. Exact approval after presenting budget, cost, model and rollback. Record actual usage ticks from xAI response, not token-only estimates.

Official source: https://docs.x.ai/developers/models ; https://docs.x.ai/developers/cost-tracking ; https://docs.x.ai/developers/model-capabilities/text/structured-outputs

**Critical:** This PR is explicitly not a real model integration and must never be described as such in a sales page.
