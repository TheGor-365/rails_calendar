# RC-038 Slice D — synthetic review readiness (read-only)

**Scope:** nonproduction Rails test or explicitly opted-in local development, with fictional MD/TXT/JSON sources only. Draft PR #38. No new HTTP endpoints, database changes, provider integrations, document generation or real customer data.

\`Studio::SyntheticReviewReadiness\` re-runs the validated owner-scoped two-source reconciliation on every call, requires the exact SHA256 comparison fingerprint, and reads only the immutable scoped owner-triage metadata receipts from Slice C. It never trusts supplied candidate status or a client-provided report. Missing reviews are \`not_reviewed\`, and explicit \`needs_information\` / \`exclude_from_draft\` / \`retain_for_review\` are counted separately. Output exposes only hashed candidate identifiers, classified states, receipt IDs and aggregate counters; never source text, filenames, freeform notes or private blob keys.

\`eligible_for_unapproved_synthetic_outline_review\` may be true only when evidence coverage is complete, every candidate has been explicitly triaged, no claim is conflicting/unknown, at least one candidate is retained, and none needs clarification. **This is an internal planning hint only, not document generation, factual verification, financial or scope approval, legal consent, or client acceptance.** \`document_generation_allowed\`, \`scope_approved\` and \`client_confirmed\` remain **false** for every response.

Hard-deny production, inactive owners and cross-tenant/foreign sources. No source text or AI output is persisted. Tests cover pending, approved-for-outline-review-only, needs-information, excluded, conflicts and unknowns, stale fingerprints, revoked owner and production denial. Run \`bin/rails test test/services/studio/synthetic_review_readiness_test.rb\` against the isolated local \`ruby_calendar_test\` after checking the Git worktree and schema state.

**Release gates unchanged:** permanent encrypted private storage, live maintained AV signatures, legal identity/consent, verified backups *and* restores, independent security/browser acceptance and separate owner-authorized release. No production deploy or real customer uploads.
