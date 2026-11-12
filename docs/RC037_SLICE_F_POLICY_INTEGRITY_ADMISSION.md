# RC-037 Slice F — verify policy audit at admission

**Status:** committed in stacked Draft PR #37; exact-head CI required before acceptance.

The existing `Studio::AiPolicyRevision.verify_chain!` was originally only invoked by explicit tests or operator verification. The zero-budget admission gate previously trusted each current `studio_ai_policies` row without checking that its snapshot matches the HMAC-linked revision chain. A privileged SQL write bypassing model callbacks could therefore change an `off` policy into `offline` while the audit disagreed.

Now `Studio::AiBudgetAdmission#admit!` verifies both existing policies (workspace default and scoped project override) on **every** synthetic offline request, after owner and environment checks and before allowing dispatch. Missing revisions, changed policy rows, altered HMAC digests and broken chains fail closed with a generic `Denied`. No implicit repair, auto-replay or fallback on corrupt audit. The existing `WorkspaceMemory::Access` denial remains `SecurityError` for revoked/foreign owners.

Regression tests simulate synthetic privileged SQL bypass on root policy, stale project override and tampered terminal revision; missing audit rows cannot be silently recreated. Positive audited policies continue to admit zero-cost offline templates. This adds no network/provider/paid calls or production access.

**Limitations:** HMAC keyed with app secret is detection, not independent WORM storage; a privileged operator with both DB and signing secret could rewrite history. This is a runtime fail-closed check, not a certification of end-to-end audit immutability, not an online cost quota service, and not real-customer processing authorization.

Remaining RC-037 tasks include read-only historical verification UX, concurrency/idempotency budget accounting for any future approved providers, retrieval ACL over encrypted clean source bytes (after RC-036 production gates), and human mobile/browser acceptance. RC-038–RC-042 are not marked complete.
