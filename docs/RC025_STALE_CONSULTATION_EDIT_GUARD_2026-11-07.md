# RC-025 — stale consultation edit guard

**Date:** 2026-11-07. **Parent:** RC-023 / PR #24. **Status:** Draft; CI, migration rehearsal and manual QA required before release.

## Scope

RC-022 row locks and audit transactions keep written before/after timestamps consistent, but cannot prevent a second browser tab submitting an obsolete form. RC-025 adds a standard Rails optimistic locking column and explicitly checks the form version **inside** the row lock before assigning submitted fields.

- Add only `consultations.lock_version` (non-null integer, default zero). Do not update title, times or descriptions, do not delete existing consultations.
- Authenticated edit form carries a hidden version. No field on creation forms or public views. The version is a concurrency token, not a permission credential.
- Updates with missing, invalid or old version return HTTP **409 Conflict** and accessible error, displaying the current saved record. Stale form edits are **not automatically merged or saved**; user must review and re-enter against current values.
- Valid edit increments the version. Reschedule audit remains atomic, reason required only when times change; rejected edits insert no history.
- Keep existing advisory overlap rule: no hard collision rejection, notification, deletion or automatic reschedule.

## Evidence and outstanding gates

- Regression tests: two simulated tabs for title and reschedule; stale/missing/forged tokens, preserved schedule and history; valid sequential edits and form input.
- **CI/Security must pass on exact final PR head.** No local owner DB migration, merge or Railway release.
- Owner's RC-024 isolated PG18 recovery gate passed: archive restored with both #3/#4, SQL and actual Active Record RC-018/RC-022 migrations and rollback passed. RC-025's new migration has **not** been applied or rolled back in the owner's isolated container.
- Still blocked for live customers: HTTPS/proxy/cookie/CSRF staging, per-client ACL, retention/erasure and actor identity; capacity/status policy unapproved.
