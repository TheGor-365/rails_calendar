# RC-010 — Continuous intervals / click-through hour cells

Date: 2026-11-06
Base: Draft RC-009 PR #9 (stacked); do not merge independently.
Status: Draft / manual QA required. No changes to main, production or database.

## Accepted user QA of RC-009

Local 127.0.0.1:3005 screenshots confirmed:
- Day 2026-11-07 shows the consultation only in the 23:00 hour.
- Day 2026-11-08 shows the same 23-hour consultation repeated in every overlapping hour, which creates unusable visual noise.
- Month November shows the consultation once in each intersected date.
- User asked for **one continuous card spanning the occupied time**, precise start/end in a 24-hour cycle, clickable time cells/interval drilldown, unique minimal UI without stock Bootstrap controls.

## RC-010 implementation

1. A fixed 24-hour vertical canvas: every 42px corresponds to one hour (00:00–24:00). Times along the left side; every hour track is clickable and opens **/calendar/hour?date=YYYY-MM-DD&hour=N**.
2. One card per consultation per displayed **date**, rendered as a single continuous interval, clipped to midnight boundaries. The card links to existing public consultation details. Actual start/end timestamps are retained on the card and in the accessible label.
3. Overlapping cards use separate horizontal lanes; collision-free clusters reclaim the full width. The calendar area scrolls horizontally if many simultaneous events exceed a mobile screen. Cards under 34px get an accessible minimum visual size; a late short card is positioned within the day but its ARIA and tooltip retain actual timestamps. (This is a display affordance, **not** a modification to booking duration.)
4. Hour interval screen lists all overlapping consultations exactly once and provides a return link to its day (anchored to the hour). A signed-in administrator can create a consultation starting at that interval; anonymous visitors cannot write.
5. No DB migration; unchanged auth, credentials, consultation validations and month UI. User-requested eventual AI intake/notifications are explicitly out of scope.

## Explicit semantics and limitations

- Each displayed hour is a half-open interval **[HH:00, next HH:00)**; an event ending exactly at the hour boundary does not overlap the next hour.
- An overnight consultation appears **once in each calendar date** that it intersects, never once per hour. Minutes are mapped to the continuous scale, not rounded to an hour.
- User timestamps remain in the app timezone (currently **UTC**); a per-user TZ/DST design remains a separate product decision, especially for 23/25-hour DST dates.
- One consultation cannot span beyond the daily visual edge; cards are clipped to day boundaries for positioning, while exact original start/end remain visible via the event link.
- When five events start in the same hour, there are five cards on distinct lanes; horizontal scroll exposes them all.
- Security: public read only; consultation mutations require existing administrator session and CSRF validation.

## Acceptance checklist

- [ ] CI and Security workflows on RC-010 final head pass.
- [ ] A 23:54→next-day 22:53 record appears **once** near the end of day 1 and **once** as a continuous ~22h53 block on day 2.
- [ ] Hour cell 09:00 opens 09:00–10:00 even if empty; hour label remains clickable even if an event overlays the track.
- [ ] Click the event itself → consultation detail; click the hour → interval detail; admin Add → new form with proper prefilled start/end.
- [ ] Two partly overlapping events appear side-by-side without hiding each other; 5+ events enable horizontal scroll within the agenda.
- [ ] Mobile 320px/390px, keyboard navigation and focus outlines; no unexpected page-wide horizontal overflow.
- [ ] Production not deployed; no merge into main.

## Local checkout on port 3005

After stopping the local calendar process and checking for uncommitted changes:

\`\`\`bash
cd ~/rails_calendar_3005
git status --short
git fetch origin
git switch --track origin/feature/rc010-continuous-time-ranges-2026-11-06
npx --yes yarn@1.22.22 build
npx --yes yarn@1.22.22 build:css
unset DATABASE_URL RAILS_ENV
bin/rails server -b 127.0.0.1 -p 3005
\`\`\`

The new screen does not require migrations. If your earlier terminal admin ENV was not persisted locally, restore your own local admin credentials before starting the Rails server; never commit or post them in chat.

Inspect:
- http://127.0.0.1:3005/calendar/day?date=2026-11-08
- http://127.0.0.1:3005/calendar/hour?date=2026-11-08&hour=09
