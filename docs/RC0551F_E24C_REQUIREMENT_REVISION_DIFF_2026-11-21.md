# Rails Calendar — E2.4c: owner-only immutable requirement revision diff (2026-11-21)

## Scope and intent
- Existing project intake, `IntakeScopeRevision` and append-only `IntakeRequirementSet` remain the sole authoritative records; **no migration, backfill, AI call or generated approval**.
- Existing local owner-only `/workspace/intakes/:id/requirements` shows the 12 most recent requirement snapshots. Each version expands a **read-only** R-ID-oriented diff against its exact predecessor (v1 compared with empty). The oldest visible version still loads its predecessor without exposing adjacent users.
- Diff compares `statement`, `status`, `acceptance_criteria`, `source` independently. Added, removed and edited rows are sorted numerically by stable R-ID; reordering rows alone is not a semantic change.
- Display is responsive (12-column Bootstrap grid) with escaped ERB text, collapsed history, RU/EN/HY/ES labels. Technical provenance changes appear as source JSON; real client-safe publication is **not enabled**.
- The service refuses cross-`project_intake_id` snapshots and reverse/equal version comparisons. Previous records remain immutable. The existing controller's owner/pilot permissions and `private, no-store` stay intact.

## Test & acceptance
- `test/services/intake/requirement_revision_diff_test.rb`: changed/added/removed, no-op order, provenance, non-mutation, cross-intake protections.
- `test/controllers/e2_client_invitation_test.rb`: create v1, manually edit v2, append v3, GET history with exact v2/v3 R-ID changes, no DB writes/AI charges, client GET 404.
- Run GitHub Rails CI: model/controller + Chrome system + PG18 fresh and baseline-upgrade; Security Audit for the exact final SHA. **Record actual result before calling this slice complete**.
- Local human check (port 3002): owner opens /workspace/library, then owner request with saved v1/v2/v3 requirements, expands history at 320/390/1440px. Confirm original strings and correct before/after; no horizontal overflow or access to another owner. User has not yet confirmed screenshots.

## Deferred / not implemented in this slice
- E2.4a: trace R-ID to specific answer and answer revision with read-only source navigation.
- E2.4b: dependencies with cycle validation, explicit exclusion constraints, reorder/split UI; do not invent accepted scope.
- E2.4d: publish-only client representation and owner technical representation.
- E2.5: separate human approvals on an immutable scope/version and change requests.

## Safety
No changes to user's local `db/schema.rb`, original port 3001, production Railway, paid Grok, `main`, customer-facing public routes or protected database. Local preview Ruby must be updated to 3.4.13 via asdf before trying current checkout.

## Tenant ACL hardening
The pre-existing `OwnerRequirementsController#load_intake!` used `workspace&.id` inside a query. With an owner lacking a Workspace, that produced `workspace_id: NULL` and could expose unassigned legacy intake drafts. The controller now returns HTTP 404 when the owner lacks a Workspace, before any query. Only explicit `workspace_id == current owner workspace ID` is accepted. Integration regression covers an orphaned intake and owners both with/without workspaces. No records are deleted or migrated. This is a local-only pilot security repair, not approval for real-client use.
