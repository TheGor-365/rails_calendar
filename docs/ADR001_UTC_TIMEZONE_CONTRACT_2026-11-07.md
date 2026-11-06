# ADR-001 — UTC scheduling baseline and future local-time display

**Date:** 2026-11-07  
**Status:** Implemented technical baseline / regional UX decision pending owner review  
**Scope:** Rails Calendar through RC-016; not an authorization to convert existing records or enable bookings with client-local zones.

## Context / current verified code

- Before this ADR, app displayed and accepted times using Rails `Time.zone`, with default effectively UTC; all screenshots showed "UTC".
- Rails app had no explicit `config.time_zone` statement, so the operational contract was implicit.
- User works in Armenia. A 09:00 UTC appointment may be 13:00 in Armenia. Calling a UTC day "Today" can differ from the user's local calendar day near midnight.
- Existing `Consultation` timestamps are persisted instants. A local input is a wall-clock value, not an instant without an associated timezone.
- Day/hour queries use exclusive upper-bound overlap `start_time < end_of_window && end_time > start_of_window`, which must not change unintentionally.
- Day schedule hardcodes 24 rows; this representation is correct for UTC but not necessarily for regions with daylight saving time (23/25-hour dates).

## Decision for current MVP

1. Explicitly pin `config.time_zone = "UTC"` and `config.active_record.default_timezone = :utc`.
2. Preserve all saved instants and their existing UTC interpretation. **No migration and no reinterpretation of historical strings.**
3. New/Edit `datetime-local` input uses whole-minute precision as established by RC-015, **interpreted as UTC**, with visible UTC guidance. UTC continues to define Today, Month, Day and Hour.
4. Continue to treat event intervals as half-open `[start_at, end_at)`, so ending exactly at midnight does not create an event in the next day.
5. Regression tests assert both 24-hour UTC schedules on external DST-change dates and exclusive midnight boundaries.
6. **Explicit non-decision:** local Armenian/client date/time display, user preferences, booking links, timezone picker, external calendar sync, recurrence and DST-safe 23/25-hour schedule are **not** approved or implemented.

## Future UX decision required before client-facing booking

Options to evaluate separately:
- UTC admin-only: least risk; display two-zone preview (`UTC` + `Asia/Yerevan`) only, never change stored instant.
- Per-user IANA timezone display and input: selectable zone, explicit offset and DST ambiguity handling; event creation maps an identified local wall time + IANA zone to a UTC instant.
- Booking policies by client/business timezone (including recurring appointments): more involved; requires choosing provider/business local day semantics, availability, gap/fold resolution, midnight and DST boundary rules.

Do **not** implement local time by simply changing `config.time_zone` from UTC to `Asia/Yerevan`: that would change Date/Today and possibly interpretation of naive `datetime-local` inputs without migration or explicit UX, and may break the current fixed 24-row display for DST regions.

## Test/release gates

- UTC pin, 24-hour day and half-open boundary regression tests pass.
- Manual: HH:MM fields, UTC labels and Today are unambiguous. Future regional time display must be separately approved.
- Admin login/logout, 8-hour session expiry, failed login rate limiting, and server-side POST/PATCH/PUT/DELETE restrictions remain regression-covered.
- Before production: replace or assess in-memory per-process login limiter with shared store (Redis or configured distributed cache); determine tenancy/client data privacy since index/show are currently **public**. Review credentials/cookie policy and staging cost. No production release until these gates are reviewed.

## Evidence / references

- [RC-015 safety record](RC015_MINUTE_PRECISION_DELETE_SAFETY_2026-11-07.md)
- [Development roadmap](RAILS_CALENDAR_DEVELOPMENT_ROADMAP_2026-11-07.md)
- [PR #16](https://github.com/TheGor-365/rails_calendar/pull/16)
- [Current UI sample](https://github.com/TheGor-365/rails_calendar/blob/fix/rc015-minute-input-delete-identity-2026-11-07/app/views/consultations/_form.html.erb)
