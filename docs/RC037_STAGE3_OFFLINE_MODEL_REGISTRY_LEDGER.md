# RC-037 Stage 3 — deterministic offline registry + $0 usage receipt

The only registered model is \`offline_document_plan_v1\`, with provider \`none\`, zero external API calls, zero tokens and $0 actual cost. A reviewed provider is not registered or executed. The dispatcher continues to require exact owner and assigned intake, explicit workspace policy, non-escalating project restrictions, \`synthetic\` data class and \`document_plan\` purpose.

Every successful deterministic proposal obtains an immutable \`Studio::AiExecutionReceipt\`, storing only tenant IDs, actor ID, purpose, model key and a SHA256 fingerprint over **boolean evidence flags**, never file bytes, client content or prompts. A repeated request with identical evidence reuses the receipt; a changed evidence set produces a different one. PostgreSQL tenant composite FK, unique index, zero-token/zero-USD CHECK constraints and no-update/no-delete Rails callbacks prevent accidental cost assertions and cross-tenant forge via Rails or SQL.

These are **completed $0 offline usage receipts**, not a paid execution authorization or a true reserve/commit/refund protocol. No external invoice, pricing registry, credentials, SMTP, or production AI available. Actual privacy policy and human review still gate all real client information.

Acceptance: model/controller/security CI, duplicate/foreign tenant tests, no client bytes, and exact-head GitHub Actions. Browser Settings QA on Linux Mint is outstanding. No Railway deployment or merge.
