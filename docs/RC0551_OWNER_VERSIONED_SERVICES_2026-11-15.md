# RC055.1 — owner-controlled versioned service offerings
Date: 2026-11-15; stacked on PR #64 exact SHA 5c12eb1b05ec28e2a989db002c58297cd2380fef.

## Invariants
- A private ProfessionalCapability is not a commercial service. Owner creates each ServiceOffering draft manually, bound to an immutable ProfessionalContextSnapshot and matching ProfessionalCapability. ServiceOffering is workspace-scoped. Delivery mode follows the approved capability; excluded/uninterested work is forbidden.
- Three distinct actions: mutable draft with (version,digest) optimistic check; owner-approved immutable ServiceOfferingVersion; explicit enabled published_version_id. Enabling is **internal only** until RC055.2, with append-only ServiceOfferingPublication audit. Never automatically publish or promote on AI suggestion or capability edits.
- New revisions copy old reviewed wording to a fresh draft bound to current approved capability; old approved and enabled versions remain unchanged until separately re-approved and re-enabled. Profile modifications and pending corrections block approval/enable; 2-click gate persists across tabs with server checks.
- No money/price/deadline promises, no paid Grok. Existing marketing /services and client /client/requests/new do not consume offerings. No implicit client contracts.
- Multi-tenant request/provider assignment and public selector with safe Other path are RC055.2; the single-owner pilot still enforces owner ACL and workspace-scoped CRUD now.

## Data
Migration 20261115190000 creates service_offerings, service_offering_versions, service_offering_publications; FK links and unique per-offering active draft; immutable digest, approval/published pointers, audit. No historical data modified. Source professional snapshots never mutate.

## Gates
Exact-SHA Rails/controller/model/system Chrome/Security CI and manual owner screenshots. Local migration blocked until a NEW PostgreSQL16 -Fc backup, SHA verification and successful isolated pg_restore plus data counts. Preserve any local db/schema.rb changes before branch switch; no main merge or Railway production deploy.
