# RC-020 — Advisory scheduling conflicts and one-hop rescheduling

**Date:** 2026-11-07. **Status:** Draft implementation awaiting exact-SHA CI + manual acceptance.  
**Parent:** [RC-019 P1 filters and duration](https://github.com/TheGor-365/rails_calendar/pull/20).

## Verified baseline
- Owner screenshots 2026-11-07: consultation #4 `Third` (13 Nov 2026 11:00–12:40 UTC) shows `Duration: 1 h 40 min`; GET `/consultations?q=Third` shows only #4; UTC 13 Nov range filter shows only #4. Desktop QA for RC-019 **PASS**. New mobile screenshots still needed.
- Owner checked out RC-019 commit `d912185`; `db/schema.rb` is locally modified following RC-018 migration. Do **not** reset/overwrite this owner-local change; inspect it and commit/reconcile separately if necessary. Untracked `.tool-versions` and `vendor/bundle/` also left alone.
- RC-018 local migration and six-call threshold `[false,false,false,false,false,true]` **PASS**; HTTP 429 through the actual login endpoint, proxy-trust, admin cookies/CSRF and staged recovery remain open release gates.
- GitHub RC-019 CI/Security green. **No production deployment or `main` merge.**

## Product decision — conflict policy is not yet adopted

An event occupies the half-open interval `[start_time, end_time)`. For consultation A and B, an overlap exists exactly when `A.start_time < B.end_time && A.end_time > B.start_time`. Two bookings with A.end == B.start are **not** a conflict. All instants are compared in the current canonical UTC timestamp format, not a browser-local timezone. When editing, exclude the record itself.

Until the owner accepts a policy for concurrent consultations, rooms, staff and bookings, **do not reject, shift or delete overlaps automatically**. This increment displays an advisory only. A future booking engine must define resources, capacity, timezone choice, confirmation and cancellation rules before enforcing capacity.

## Implemented read-only features
- An optimized bounded overlap query on `Consultation`, with start/id order and self-exclusion; no new tables, writes or dependency.
- Admin-only overlap callout on consultation details and loaded new/edit form schedules with links and UTC ranges (up to ten entries, overflow indicator).
- Explicit warning that form warnings are based on **loaded** values and are rechecked after saving, not a live check while typing.
- One-click `Reschedule` link on authenticated consultation index points to the existing edit form's start-time field. Existing `Edit this consultation` link on details remains intact. Guests do not receive write links or overlap detail callouts.
- Mobile-friendly Slate & Tide styling, icon + visible label, >42px touch targets, no new icon package.

## Test and acceptance contract
- [ ] Rails CI and Security pass on final SHA, including model interval boundaries and unsaved candidate, read-only guest views, admin overlap and index action, update collision advisory, prefilling a new form from calendar, Chrome 320/390/430 one-hop navigation/no overflow/fixed dock.
- [ ] Owner local desktop test: navigate to all consultations; logged-in user sees `Reschedule` on existing records; tap goes to `/consultations/:id/edit#consultation_start_time`. No change to record until explicit Update.
- [ ] To test advisory, create **only an approved disposable** consultation (optional). Do not create or delete any demo record without direction. The automated CI uses isolated fixtures, so user need not manually introduce overlaps.
- [ ] Mobile (320/390/430): dock pinned; reschedule button visible, form reachable, overlaps readable without horizontal scrolling.
- [ ] Do not delete #3 or #4. Do not reset local schema or modify Railway/main.

## Remaining gates / next P1
- P0: real HTTP 429 test; account/session/CSRF/proxy; record-specific Delete confirmation **Cancel**; staging database restore and tenant privacy.
- P1: user-approved collision/capacity policy, audited reschedule history or cancellation lifecycle; avoid silently overwriting confirmed customer commitments.
- P2: Rails AI intake, versioned requirements, manually approved scope and estimates.
