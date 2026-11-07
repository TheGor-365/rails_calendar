# RC-028 — project timeline from approved specification

**Date:** 2026-11-08. **Parent:** RC-027 [Draft PR #27](https://github.com/TheGor-365/rails_calendar/pull/27). **Status:** Draft implementation and synthetic-only regression; DO NOT MERGE/DEPLOY until owner staging gate.

## Narrow functionality

- On RC-027 intake, a **human-approved version** of the specification contains tentative phases with \`suggested_work_days\`. Admin explicitly chooses a proposed project start date and confirms materialization. One independent \`project_milestones\` row is created for each phase; each references the exact approved spec version and belongs to one intake.
- Dates are **date-only UTC calendar days** and count Monday–Friday. Holidays, resource capacity, billable business days and regional time zones are not assumed. The owner must review every date; these are NOT promised delivery dates.
- The intake page displays a private project milestone list **and a month calendar**. Non-admin access uses the existing RC-027 same-browser demo session and only sees its own intake. This is not full multi-user tenant ACL.
- Duplicate scheduling is fail-closed with HTTP 409; malformed dates or absent explicit confirmation return HTTP 422. Each schedule is created under an intake row lock. Nothing touches shared consultation records.
- No auto-integration with the shared admin consultations calendar, no external alerts, contract/budget claims, real paid engagements, or task-completion buttons.

## Test/release

- Model/HTTP tests: admin required, approved spec required, date validation, weekend skipping, duplicate guard, scoped calendar markup, no changes to consultations or unexpected messages.
- Real Grok calls still disabled by default; xAI secret not in repo.
- Requires final CI+Security PASS, isolated RC-027+RC-028 Active Record forward/rollback on disposable DB, staging HTTPS/cookie/proxy/CSRF checks, consent and identity/retention policy before genuine customers.
- This is one portfolio **synthetic demo**, not a sold or deployed multi-tenant SaaS.

## Next product priorities

1. Admin editing of proposed scope/durations and date adjustments without breaking approved version; client accepts an immutable spec+timeline version only after identity verification.
2. Per-client auth and role/ownership model, anti-abuse controls and deletion/export policy.
3. Progress updates, document exports (MD/PDF), notification opt-in, outcome metrics.
