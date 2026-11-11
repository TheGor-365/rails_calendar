# RC-037 Stage 1 — offline-first AI policy foundation (Draft, $0)

Scope: nonproduction synthetic owner-only, stacked on RC-036 Draft PR #36. No model SDK, keys, HTTP provider, production deploy, public client content, or paid services.

## Implemented

- \`Studio::AiPolicy\` keeps a workspace default and optional per-assigned-intake restriction. With no workspace policy the dispatcher is **OFF**, not implicitly permitted.
- PostgreSQL partial unique indexes prevent duplicate defaults/project policies. Composite intake/workspace FK rejects cross-tenant inserts even if Rails validation is bypassed. Legacy unassigned intakes are rejected.
- Explicit mode \`off/offline/reviewed_provider\`; \`reviewed_provider\` is **configuration only** and never enables a provider. Allowed-purpose and data-class arrays are allowlisted (\`document_plan\`, \`synthetic\` only). Token and USD budget ceilings are configured as nonnegative fields, not live billing reservations.
- \`Studio::OfflineAiDispatcher\` rechecks owner/membership/assigned project on each call. Only test or explicitly opted-in synthetic development is usable. \`production\` hard-denied. Precedence: system nonproduction and zero spend > owner/tenant ACL > workspace mode > project restriction > requested mode/purpose/data class.
- Only deterministic \`DocumentGenerationPlan\` output from boolean evidence. Results are proposals requiring human review; no file bytes, retrieval, provider, financial estimates, client approval, tokens or cost. An apparent \`ready_to_propose\` is NOT verified source evidence.

## Current limits and next steps

- This is a service-level policy foundation, **not yet the Settings UI/API or an accounting reservation ledger**.
- Actual external providers remain unimplemented, and may not be connected or charged without separate user approval and privacy/security acceptance.
- Next: owner-only local Settings UI/API with validated scoped inputs and negative HTTP/CSRF checks; typed provider/model registry exposing \`none\` only; no actual billable invocation.
- Test: \`bin/rails test test/services/studio/offline_ai_dispatcher_test.rb\` on a disposable test Postgres DB; validate full exact-head Actions before calling Stage 1 complete.
- Railway production, PR merge and client-file gates remain unchanged.
