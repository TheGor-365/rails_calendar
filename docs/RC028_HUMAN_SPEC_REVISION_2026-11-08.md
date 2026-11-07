# RC-028 — Human-reviewed immutable specification revisions

**Parent:** RC-027 Draft PR #27. **Status:** Draft; no external deployment or live-client records.

Value: an AI-generated/TEMPLATE draft is not a safe handoff unless the developer can edit content. Admin-only review form edits summary, goals, deliverables, acceptance criteria, unknowns and exclusions; saving creates version N+1 with source `human`, leaving generated version and attribution intact. Milestone suggestions remain tentative.

Constraints:
- Explicit per-field max lengths and per-section entry counts; Rails HTML escaping, session/CSRF protection, owner-only actions.
- Lock intake row and compare expected version to latest draft (HTTP 409 on stale form). Invalid text returns HTTP 422 and does not create a version.
- Publishing remains a separate administrator action; no email, notifications, approved money or dates.
- Client views latest **published** spec even if owner is editing a newer internal draft. Anonymous draft content never leaks. Review acknowledgement remains demo-only, not signed acceptance.
- Existing `consultations` and local owner data untouched; no new migration or secret.

Acceptance: CI server/browser and Security audit on exact final SHA, tests for immutable generated original, new human revision, rejected stale form, previous published visibility and admin ACL. Staging, tenant identities, calendar date assignment and real client consent remain separate release gates.
