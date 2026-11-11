# RC-038 Slice C — exact-owner immutable synthetic triage decisions

**Scope:** Rails test / explicitly opted-in development only, fictional documents only. Draft PR #38, no real client uploads, production routes, external AI, source-text persistence or automatic approvals.

\`Studio::SyntheticReviewTriage\` re-runs the two existing \`SyntheticSourceNormalizer\` validations via \`SyntheticSourceReconciliation\` on each call. The operator supplies a SHA256 comparison digest, exact candidate fact ID and typed \`REVIEW-SYNTHETIC-<first12digest>\` confirmation. The backend does NOT trust a supplied status or raw previously generated comparison. Actor must still be an active owner of the exact workspace, client and assigned intake. Quarantined source bytes remain unavailable.

An operator may record one of \`needs_information\`, \`retain_for_review\`, \`exclude_from_draft\`. The latter two do NOT constitute a client acceptance, a verified fact, a release permission or financial/scope approval. Unknown/conflicting candidates cannot be retained for review without resolving uncertainty. A same-source-pair/candidate record is immutable and idempotent on exact retry; a different decision for the same comparison is refused until a new source revision. Row-lock serializes concurrent writes.

Only workspace/client/intake/source/actor numeric IDs, digest, hashed candidate ID, candidate state, resolution and timestamps are stored. No source text, untrusted instructions, filenames, freeform comment or credential is saved. PostgreSQL composite tenant FKs for BOTH source identities + intake/client and check constraints reject forged cross-tenant writes; model rejects updates/deletes. Legacy unassigned intakes stay excluded.

**Not implemented:** full fact-graph storage, client approval/consent, external data ingestion, draft document revisions or a public owner UI. This is a nonproduction demonstration of safe review provenance, not a production audit WORM store. Production remains blocked by permanent encrypted private storage, maintained antivirus database, reviewed identity and consent policy, audited backups/restore, secure delivery and owner sign-off.

Run on isolated \`ruby_calendar_test\`: \`bin/rails test test/services/studio/synthetic_review_triage_test.rb\`. Exact-head GitHub Actions must be green before acceptance.
