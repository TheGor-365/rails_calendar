# ADR-002 — Scheduling capacity and reschedule audit (proposed)

**Date:** 2026-11-07  
**Status:** PARTIALLY IMPLEMENTED DRAFT — audit of admin-saved time changes; capacity policy NOT APPROVED.  
**Parent:** RC-022. **Timezone:** UTC as in [ADR-001](ADR001_UTC_TIMEZONE_CONTRACT_2026-11-07.md).

## Context and source of truth

RC-020 detects half-open `[start_time, end_time)` overlaps for informational display only. The app has **one shared administrator credential**, no distinct staff identities, resources, booked/confirmed status or tenant-specific access control. User screenshots verify #4 "Third" opens an edit form prefilled with 13 Nov 2026 11:00–12:40 UTC; a successful reschedule and client authorization have NOT been visually verified.

### Decision A — implemented in Draft RC-022

On an authenticated administrator **update that changes start or end time**, require a short reason (1–500 characters) and atomically store an audit snapshot with consultation ID, UTC before/after times, server-chosen actor label `administrator`, reason and insertion timestamp. Do not create a reschedule event for title/description-only changes or rejected updates. This is **an admin change log, not proof of client consent**, and the actor label identifies the shared privileged role, **not an individual human**.

Read the most recent 20 entries from each consultation detail page **only while signed in as administrator**; no guest or external API endpoint. The reason is filtered from Rails request parameter logs, but remains in the protected database and its backups. Do not include secrets or unnecessary client personal data in reasons.

**Atomicity:** the consultation row is locked; its write and the history insertion occur inside the same database transaction. Error/rejection must not insert a history row or change the consultation. This does **not yet** prevent stale-form overwrites across two already-open browser tabs; optimistic locking is an additional recommended gate before multiple administrators.

**Retention/immutability caveat:** consultation records currently have hard delete. The audit table intentionally holds an independent `consultation_id` snapshot without foreign-key CASCADE, so past reschedules survive record deletion in the database. Active Record prevents update/destroy through this model. Privileged direct SQL and `update_columns` bypass this application-level policy; database-level append-only permissions/triggers and retention/erasure procedures need approval before real customer data. This is not a forensic-grade audit log yet.

**Migration:** additive `consultation_reschedule_events` table. No existing consultations are rewritten, truncated, migrated or automatically rescheduled. Production/staging migration and rollback require backup and owner approval.

### Decision B — not adopted: who can overlap and when?

Proposed domain alternatives requiring explicit business choice:

| Mode | Capacity | Collision behavior | Fits |
| --- | --- | --- | --- |
| Informational (current) | Undefined | Warn, allow save | Existing demo and multi-project work |
| Single-provider confirmed slot | One confirmed engagement at a time | Reject *only* confirmed conflicts for same provider | Real one-to-one consultations |
| Resource-capacity booking | Per provider/team/room, configurable >1 | Check capacity on confirmed records only, with race-safe locking | Multi-employee teams and concurrent services |

**Proposal, not policy:** start with informational mode until specific `resource_id`, `status` (`draft/confirmed/cancelled`), permitted overlap classes and approval lifecycle have been established. Never infer an exclusive provider from a consultation title. Intervals touching exactly at an endpoint remain non-overlapping.

### Decision C — not adopted: human approval and change lifecycle

Distinguish:
- Administrator **saved** a revised calendar time (implemented technical audit).
- Service provider and client **agreed** to that time (not represented or established by this release).
- Cancellation, no-show, rebooking, reminders and notification delivery (future business lifecycles, not included).

Do not automatically notify clients, modify signed commitments, charge fees or initiate external actions from a calendar edit. Once authenticated users, parties, scope versions and confirmations exist, extend history with durable actor identity, client approval record and immutable reference to the approved scope/version. Define tenant filtering and privacy/retention before real client use.

## Open release gates

- [ ] Owner accepts the meaning of the single shared admin `actor_label`, required reason and retention behavior.
- [ ] Final SHA CI+Security and 320/390/430 + desktop visual QA.
- [ ] Isolated staged migration + verified backup/restore + recovery plan; **no direct local/production DB migration yet**.
- [ ] Optimistic lock or stale edit guard before simultaneous editors.
- [ ] P0 HTTPS reverse proxy, secure cookie/CSRF, tenant/row-level ACL and actual staging recovery.
- [ ] Resource/capacity/status model and concrete concurrency test before any hard overlap enforcement.
