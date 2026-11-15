# RC055.1a — Automatic private catalogue from approved profile

2026-11-15. Base PR #65 exact SHA 7d1a8f398decd26422d95a3ad0c0aaf522c51d5e.

The owner correctly challenged manually duplicating the six-step AI-assisted
onboarding in the service catalog. The approved ProfessionalContextSnapshot
already stores desired_services, capabilities, exclusions and AI-assisted
owner-reviewed summaries. These source records are the canonical facts.
An offering is a versioned commercial projection, not a competing profile.

## Implemented
- OwnerServices::AutoCatalogue: deterministic, offline rules_v1 commercial
  draft generator. Only approved desired_services with eligible matching
  capabilities. It produces explicit scope, exclusions, inputs and safe
  conditional wording. No made-up evidence, pricing, date or AI completion.
- A single backfill POST button on /workspace/services fills existing v1.
  No GET mutation; no repeated manual re-entry. Stable auto-<interest> keys
  and per-snapshot version identity make reruns idempotent.
- Future owner profile approval triggers auto-generation after the immutable
  snapshot has been committed. The owner can still manually create/edit.
- A new approved context generates **only a new private draft revision** of
  previously approved auto-offerings. It does not replace their approved
  version or republish anything. Existing drafts are never overwritten.
- Manual svc-* offerings and old client intakes remain untouched.
- The source snapshot is pinned on every version. auto- key is provenance for
  rules_v1; do not label it as a new Grok response. New AI rewriting is a
  later explicit cost/consent gated refinement with provenance metadata.
- Internal enabled offerings are still invisible to clients; RC055.2 must
  enforce current source snapshot and approval before displaying a selector.

No DB migrations, external calls, background jobs or production changes.
Local browser acceptance after exact SHA Rails/Chrome/Security CI.
