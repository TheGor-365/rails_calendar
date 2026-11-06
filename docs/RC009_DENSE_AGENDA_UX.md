# RC-009 — Dense daily agenda, month density and original UI language

Date: 2026-11-06
Parent: [Draft RC-008 PR #8](https://github.com/TheGor-365/rails_calendar/pull/8).
Status: staged Draft PR only. Do not merge to main or deploy.

## User-confirmed starting point

- Successful local administrator sign-in on 127.0.0.1:3005.
- Consultation create/display and month rendering confirmed by screenshots.
- Screenshots show the older month navigation without the Day action (the user's local version has not been confirmed switched to RC-008).
- Requested: all 24 hours visible in the day view as compact rows; empty hours collapsed; busy hours expanded; multiple events in an hour viewable without unlimited height; month cells show event count and cap previews. No generic Bootstrap-styled controls; original understated UI and bottom-rule inputs.

## Changes

- Day view uses all **24 DOM rows** (00:00–23:00 in app timezone). Empty rows show time + "Free" in a ~30px line. Busy rows use native HTML \`<details open>\`, showing time, per-hour event count and scrollable event list. Clicking its summary collapses/expands without JavaScript.
- Each hour has an admin-only "Add at HH:00" link. All mutations remain restricted by the existing controller authorization.
- Multiple overlapping events appear in the same hour; the list caps its *visible height*, **not the record count**, and becomes scrollable for density.
- Month table counts all events for each visible day, caps previews to 2 and links "+ N more" to the hourly day page. Month data query uses interval-overlap semantics, including sessions that began before the displayed month; overnight carryovers marked "Ongoing".
- Introduced original "Slate & Tide" graphical system: compact typography, graphite/muted teal, editorial dividers, custom navigation/links/buttons, minimal surfaces. Bootstrap is retained for layout utilities only.
- Admin/consultation forms and login use \`rc-input\` fields with a single underline; native date/time picker remains for accessibility and keyboard use. Server-side date validation unchanged.
- No migration or alterations to Redis, sessions, authentication, credentials, API, AI, Capacitor or live deployment.

## Local acceptance / gates

1. Automated Rails integration/browser tests and GitHub Security Audit must pass on this PR head. Inspect both runs.
2. Desktop: month calendar shows counts, max two previews, "+ N more" when 3+ events; click any date to open day.
3. Day: exactly 24 hours; busy hour expanded, empty compact; summary click collapses/reopens; 5+ events scroll in their one hour; manual admin Add launches form at the hour.
4. Mobile: 320px and 390px; no body horizontal overflow, month table intentionally scrolls horizontally, day rows fit width, keyboard focus visible; date/time native inputs.
5. Public visitor can browse month and day; cannot see add or mutate; administrator create/edit/delete still work.
6. Decide timezone policy before real users. Current server zone UTC; no customer-specific TZ settings yet.

## Local checkout

Stop only the Rails Calendar process on :3005, and after checking \`git status --short\` is empty, run:

\`\`\`bash
cd ~/rails_calendar_3005
git fetch origin
git switch --track origin/feature/rc009-dense-day-agenda-design-system-2026-11-06
npx --yes yarn@1.22.22 build
npx --yes yarn@1.22.22 build:css
unset DATABASE_URL RAILS_ENV
bin/rails server -b 127.0.0.1 -p 3005
\`\`\`

If session secrets were exported in an earlier shell that has since been closed, supply new local admin ENV variables securely in the same shell before starting the server. Do not share or commit them.

QA destination: \`http://127.0.0.1:3005/calendar/day?date=2026-11-07\`.

Next product blocks remain AI intake, approvals/quotes, scheduling constraints and notifications; RC-009 is a pure UX increment.
