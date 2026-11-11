# RC-037 Slice A — zero-cost offline-first policy registry

**Draft, stacked on RC-036 PR #36; no deployment or merge.** No actual AI provider, API token, network egress, customer content or new billable services.

- `studio_ai_policies` stores one workspace default and optional project-specific **restrictive** policy: mode `off/offline/reviewed_provider`, allowlisted purposes, preference-only token/USD caps and external-consent flag. New rows default `off`, zero budgets, no consent.
- `Studio::OfflineAiDispatcher` accepts active workspace owner, matching scoped intake, `synthetic` data class, and Rails test or explicit `RC_STUDIO_AI_OFFLINE=true` local development only. Rails production hard-denied. No arbitrary prompt bytes, provider client libraries, API keys or network operations.
- Projects can narrow permissions but never broaden workspace defaults. A `reviewed_provider` preference remains unavailable and falls back only to a clearly marked unapproved static internal outline. Every response reports zero external calls, zero billed tokens/USD.
- PostgreSQL composite FK and partial unique indexes protect tenant scope, default uniqueness and project overrides. Tests assert SQL forgery blocked, foreign/revoked ACL, mode escalation denied, data-class restrictions and cost zero.

**Not yet RC-037 production acceptance:** AI Settings UI, provider-selection approval and vetted pricing, token/USD reservation accounting and per-period enforcement, prompt registry/schema validator, retrieval authorization and injection/adversarial E2E. External AI remains OFF. Before enabling any provider, new separate owner approval and security/legal review are required.
