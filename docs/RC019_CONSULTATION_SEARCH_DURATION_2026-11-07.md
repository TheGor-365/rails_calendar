# RC-019 — Consultation search, UTC filters, pagination and truthful duration

**Date:** 2026-11-07  
**Status:** CI + Security SUCCESS on code SHA `01e37461439af8725db2d853d0fa21d5dc2fb3d7` (82 Rails tests / 567 assertions + 17 Chrome tests / 210 assertions = 99 tests / 777 assertions, 0 failures/errors/skips). Owner local browser acceptance pending.  
**Parent:** [RC-018 shared login throttle](https://github.com/TheGor-365/rails_calendar/pull/19)

## Owner-confirmed baseline

- Latest Linux Mint checkout of RC-018 is `24bc1ca`.
- Local PostgreSQL migration 20261107123000 succeeded; `LOGIN_TABLE=true`.
- Records `#3 RC-P0 QA — DELETE AFTER TEST` and `#4 Third` remained present.
- Read-only model test using documentation IP `192.0.2.249` returned `[false, false, false, false, false, true]`. This verifies the six-call throttle decision locally, **not an end-to-end login HTTP 429 or multi-process proxy validation**.
- Screenshot shows `#4 Third` continuing to display as a single interval from 11:00 to 12:40 UTC in the day grid.
- One important UX defect in the existing show view: Rails `distance_of_time_in_words` described 100 minutes as `about 2 hours`.
- **Unclosed P0 gates:** manual browser check of record-specific delete confirmation (cancel only), real POST login/rate-limit behavior, proxy trust, secret/CSRF audit, recovery drill and production client ownership. Nothing in P1 authorizes skipping these.

## Implementation contract

1. Replace approximate duration phrase with an explicit **hour/minute** duration. 100 minutes → `1 h 40 min`; 30 minutes → `30 min`; 60 minutes → `1 h`. Historical records that include seconds are rounded for display and clearly marked **approximately**, without modifying the actual instants.
2. Consultation index supports GET `q` (case-insensitive literal substring of **title**, with SQL LIKE escaping), UTC `from`/`to` inclusive days, and status `all/upcoming/ongoing/past`. A selected date range means **any portion of an event overlaps the range**, respecting half-open `[start,end)`: an event ending at midnight is *not* included next day.
3. Date inputs are strict `YYYY-MM-DD`, years 2000–2100, `from <= to`. Invalid input shows an accessible error and **no unfiltered records**, rather than silently returning all records. Search length max 120 characters. Unrecognised status is rejected.
4. Stable ordering `start_time, id` and server-side pages of 20 records. Safe invalid/very large page handling; previous/next links preserve active search parameters.
5. Empty and no-match states are distinct. Filter labels include UTC, visible text + existing icons, search semantics and accessible result count; mobile form collapses to 1 column at 320–575px, 2 columns on tablets, 4 on desktop.
6. Existing read/private gate stays on `ConsultationsController#index`; filtering adds **no new API or read permission** and does not bypass `RAILS_CALENDAR_PUBLIC_DEMO_MODE=false`.
7. No additional gems, migrations, business model changes, paid dependencies, Railway changes, `main` changes, or deletion of #3/#4.

## Acceptance

- [x] [CI #42378372827](https://github.com/TheGor-365/rails_calendar/actions/runs/42378372827) and [Security #42378372681](https://github.com/TheGor-365/rails_calendar/actions/runs/42378372681) SUCCESS on code SHA `01e3746`. Latest documentation commit will re-trigger verification.
- [x] Integration tests pass: date boundaries, literal wildcard title matching, lifecycle status, malformed input, pagination, private read control.
- [x] Chrome system tests pass: filters/deep links at 320/390/430 px, no horizontal overflow, dock unchanged, exact show duration.
- [ ] Local owner: #4 detail duration **1 h 40 min**, filter `q=Third` shows #4, filter `from=2026-11-13&to=2026-11-13` shows #4, Clear returns #3 and #4, mobile dock fixed.
- [ ] Do not confirm any deletion; record-specific prompt still awaits manual Cancel QA.

## Next implementation queue

1. Complete P0 release security and staging backup/restore decision before any public client use.
2. P1: admin edit/reschedule UI, explicit scheduling conflict policy, future page/record paging as volume grows.
3. P2: narrow Rails AI Intake (human-approved scope and proposal versions, explicit client ownership).
