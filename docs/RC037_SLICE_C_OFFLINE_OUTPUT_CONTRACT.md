# RC-037 Slice C — typed offline output contract & immutable template registry

Stacked Draft PR #37 only. This is a **deterministic offline** implementation, not a production LLM interface.

- `Studio::OfflineTemplateRegistry` defines three versioned, fixed synthetic templates: `clarify`, `source_outline`, `document_proposal`. They never interpolate owner/client body text, URLs, file contents, credentials or untrusted document instructions.
- `Studio::OfflineOutputContract` validates the **exact** returned hash shape: registered purpose, stable template/schema versions, unverified classification, `needs_human_review`, explicit offline provider, nonnegative metadata count, exact registered template text, `external_calls=tokens_billed=billable_usd=0`, `auto_approved=false`. Unknown fields, revised prompts, extra billing, fake approval and altered text fail closed.
- `Studio::OfflineAiDispatcher` now validates every generated template payload before returning it. The earlier workspace/tenant/consent and $0 safety gates remain.

This **does not** validate an external model response because none is called; no prompt injection can be treated as authoritative evidence. Pending RC-037 release work: budget reservation with a real approved provider, explicit external-use consent and privacy review, schema governance for third-party outputs, retrieval ACL, model evaluation, request logs with no PII, and manual browser acceptance.

Tests: `bin/rails test test/services/studio/offline_output_contract_test.rb`, full GitHub CI exact HEAD after commit. No paid infrastructure, merge or deployment.
