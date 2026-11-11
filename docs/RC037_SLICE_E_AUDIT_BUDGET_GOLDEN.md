# RC-037 Stage E — auditable AI policy changes (nonproduction only)

Each normal ActiveRecord `Studio::AiPolicy` create/change appends a scoped `Studio::AiPolicyRevision` in the same transaction. Recorded values are strictly allowlisted mode, permitted purposes, numeric preference caps and external consent boolean. No raw prompts, client names, source bodies, filenames, API secrets, external calls or provider output are persisted.

For owner UI saves, the authenticated owner must have an active workspace membership and the event is tagged `owner_ui` with a user ID. Direct internal/test model writes with no actor are labelled `internal_unattributed`, never falsely attributed to a person. Each entry contains the previous SHA256 HMAC digest, sequential revision and a digest of canonical scope/actor/action/attributes/timestamp. `Studio::AiPolicyRevision.verify_chain!(policy: policy)` checks order, linkage, signatures and current policy snapshot. Composite PostgreSQL foreign keys prevent cross-workspace policy spoofing.

**Immutability boundary:** supported Rails update/destroy APIs deny revision edits. The HMAC chain detects many in-place DB modifications but is *not a substitute for* independent write-once storage, least-privilege DB roles or separately verified backups; direct SQL and privileged DBA operations can bypass model callbacks/delete a tail. Existing production remains blocked. `external_consent` is a recorded preference, not proof of lawful consent or permission for paid API calls.

Acceptance: owner policy UI saves create HMAC-linked revisions, unchanged saves do not, forged tenant FK denied, mutation caught by verifier, revoked or foreign actor denied. This is Slice E phase 1; zero-cost provider admission and golden fixtures follow in phase 2.
