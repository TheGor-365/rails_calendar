# RC-017 — Private-by-default calendar release gate (2026-11-07)

**Status:** implemented on a stacked Draft branch; CI and local QA must pass before acceptance.

## Why

The existing Rails Calendar was designed as an educational/demo schedule: public month/day/hour views plus public consultation index and full details. These routes may expose titles, descriptions, and dates of future **real client** consultations. Admin-only mutation is not sufficient protection for sensitive client metadata. A full customer multi-tenant access model is **not yet implemented**.

## Decision and behavior

The environment variable `RAILS_CALENDAR_PUBLIC_DEMO_MODE` controls **anonymous read access**:

| Environment | Unset flag | `true` | `false` or any other value |
|---|---|---|---|
| Development/test | Public demo (existing behavior) | Public demo | Private admin-only |
| Production | **Private admin-only** | **Public demo (explicit opt-in)** | Private admin-only |

- Public demo exposes **all** existing consultation records through month/day/hour, index and detail. Set the flag to exactly `true` in production **only for a separate database with approved synthetic/public data and reviewed consent**, never for client requests.
- Private mode redirects anonymous `GET /`, `GET /calendar/day`, `GET /calendar/hour`, `GET /consultations`, `GET /consultations/:id` to `/admin/login`; authorized admin can view all. Admin login remains public.
- The previous server-side create/edit/update/delete admin restrictions are unchanged. The guest mobile dock can still point to an entry that requires login; no action is hidden behind a UI-only guard.
- This is a **temporary access gate**, not a multiuser permissions feature. A shared administrator cannot substitute for per-client ownership/tenant-scoped records, membership, privacy policies and audit records. Do not store actual client data in a globally public demo DB.
- If `RAILS_CALENDAR_PUBLIC_DEMO_MODE` is unset on production, the gate fails closed (private). Arbitrary values like `1`, `yes`, or `TRUE` do not opt in.
- No migrations, data updates, new paid services, secrets, or changes to `main`/Railway.

## Acceptance and tests

1. CI and Security success on **same** final PR head SHA.
2. Integration checks verify anonymous denial on all five read endpoints in private mode and successful admin read, while default development/test demo remains public.
3. Guest mutation endpoints are forbidden even when public demo reads are on.
4. Production default private is explicitly verified; malformed environment values fail closed.
5. Owner: local test with `RAILS_CALENDAR_PUBLIC_DEMO_MODE=false` and unsigned browser, then sign-in and check monthly/day/show access; optional only after prior RC-015 visual checks. Do not delete #3 or #4.

## Remaining P0 release blockers

- In-memory, **per-process** login throttle must be replaced/reviewed for a distributed deployment.
- Cookie/CSRF audit, secret provision/rotation, HTTPS/proxy and sensitive log redaction must be checked in staging.
- Public demo must be segregated from any real client data; proper `User/ClientRequest` ownership is required before real customer-facing application.
- Admin/client regional timezone semantics (UTC and Armenia) not yet chosen; [ADR-001](ADR001_UTC_TIMEZONE_CONTRACT_2026-11-07.md) intentionally preserves existing UTC.
- PR #4 is superseded and must not be merged. All other stacked PRs remain Draft pending review and explicit approval.

## Evidence / related

- [RC-016 UTC/access](https://github.com/TheGor-365/rails_calendar/pull/17)
- [RC-015 time/delete safety](RC015_MINUTE_PRECISION_DELETE_SAFETY_2026-11-07.md)
- [Roadmap](RAILS_CALENDAR_DEVELOPMENT_ROADMAP_2026-11-07.md)
