# RC-011 — Local boot, calendar navigation and QA handoff (2026-11-06)

Base: Draft PR #10, feature/rc010-continuous-time-ranges-2026-11-06. Current: Draft PR #11, fix/rc011-local-boot-navigation-2026-11-06.

## Verified local problem
User switched to RC-010 but new Puma failed to start: A server is already running (pid 285048, local project tmp/pids/server.pid). The old Puma continued serving changed source and raised uninitialized constant PagesController::Calendar at Calendar::DayEventLayout.new. RC-010 CI #144 passed on a clean boot. Do not assume a fresh-boot Zeitwerk regression without reproducing it.
Bootstrap/Dart Sass v1 emitted over 2000 deprecation warnings during successful CSS compilation; these are not the cause of NameError.

## RC-011 changes
- Safe bash bin/run-calendar-3005: checks port ownership, refuses if occupied, handles only a confirmed stale project PID, validates Calendar::DayEventLayout on a fresh Rails runner, builds assets and starts Puma. No process kill, no DB write. Use bash (GitHub Contents API does not guarantee executable mode).
- CSS build suppresses only known deprecated Sass dependency notices, not compilation failures. Local launcher chooses Rails log_level warn; direct development server can still use debug.
- Whole month cell is a click target, except independent event-card links (which open the detail record). Day number stays accessible; CSS controls stacking.
- Top navigation Day renamed Today · 24h; month Today also opens today's 24h schedule.
- Consultation index is a chronological registry, not a repeat of the full details view. List and details provide direct links back to the correct day/event; admin write permissions unchanged.
- Integration + Chrome system tests added/updated for navigation and links.

## QA first
1. Verify CI and Security success on the FINAL SHA of Draft PR #11; older green SHA does not count.
2. In the old Rails Calendar terminal press Ctrl+C; ensure 127.0.0.1:3005 is free. Never pkill ruby, killall rails, or remove a live PID blindly.
3. git status --short; git fetch origin; git switch --track origin/fix/rc011-local-boot-navigation-2026-11-06 (or git switch fix/rc011-local-boot-navigation-2026-11-06 if existing locally). No destructive reset of local edits.
4. bash bin/run-calendar-3005
5. Test http://127.0.0.1:3005/calendar/day?date=2026-11-08: one spanning card 00:00–22:53 UTC, full 24-hour axis, no NameError.
6. Click a blank portion of day cell → day; event preview → detail; detail → anchored event; Today → current UTC day; hour → one-hour interval.
7. Check 320/390px and desktop, mouse/keyboard, event overlap scroll, no unexpected body horizontal scroll.
8. Verify admin-only create/edit/delete, public read-only; capture screenshots; update Notion/ClickUp only after confirmed API result.

## Next engineering increments after acceptance
- Timezone and DST policy, event vs consultation domain, privacy and client roles (current public consult records are demo-only).
- Versioned AI intake for first vertical Rails freelancing: conversation → verified spec → human-approved estimate and milestones → calendar.
- Notifications, client approvals, project progress, API; Vite + Capacitor mobile and app-store submissions only later, not currently implemented.

Detailed downloadable master from conversation: RAILS_CALENDAR_MASTER_HANDOFF_2026-11-06.md.
PR links: https://github.com/TheGor-365/rails_calendar/pull/9 ; https://github.com/TheGor-365/rails_calendar/pull/10 ; https://github.com/TheGor-365/rails_calendar/pull/11
RC-010 handoff: https://github.com/TheGor-365/rails_calendar/blob/feature/rc010-continuous-time-ranges-2026-11-06/docs/RC010_CONTINUOUS_INTERVALS_HANDOFF.md
RC-010 CI: https://github.com/TheGor-365/rails_calendar/actions/runs/42273087555
RC-010 Security: https://github.com/TheGor-365/rails_calendar/actions/runs/42273087565
Notion checkpoint: https://app.notion.com/p/4102cdc8e765819c84bbe93e112c094f
