# C2.4a — White Atlas browser-defect repair and commercial UI

**Owner screenshots 2026-11-23. Status: code staged for CI, no updated owner browser acceptance, no production deployment.**

## Baseline and verified observations

Local owner and verified fictional client both render correctly after Ruby 3.4.13 restart. Owner calendar month/day/hour, workspace, cabinet, AI launcher, library, requests and intake-new were viewed; route presence does not prove saves, charged AI or completion of client flow. Screenshots identify: pale month grid; cluttered mobile plus button; month title wrongly says Consultations for many event kinds; owner activity at 22:37 not legible inside hour grid; duplicated native summary triangle and custom chevron; bottom sign-out adds an unwanted sixth dock action; outdated teaching copy and inconsistent owner dashboard section headings.

## Scoped changes

- Month/day: stronger neutral lines using existing --ws color tokens; typed classes and existing Activity::Presenter icon; month now shows generic Events in RU/EN/HY/ES; 7-column mobile cells become 60px high; mobile month 'plus' suppressed (mobile main create action retained).
- Hour: read-only projection of @day_activity_by_hour into the actual a.rc-hour-band, showing type-specific icon, title, precise time and number of extra events. Existing event details and 42px/hour consultation lane layout preserved. The owner recap and activity disclosure remain.
- Details: global browser marker suppressed only if same summary has custom .bi-chevron-down; custom chevron retained. Activity history becomes one aligned row.
- Mobile nav: owner bottom logout removed (now 5 links); client bottom logout removed (now 3 links); header logout remains; legacy standalone admin logout retained.
- Workspace 'Outgoing invitations' and 'Tools' use the same White Atlas semantic icon heading component.
- Learner phrases removed from request hero, request owner detail, work-step badge, requests header, month/day instructional paragraphs; 19 related intake translations updated in each of four locales.
- Existing intake checkbox for future AI interview data transfer remains **as a real informed authorization** because backend requires it and may send content to Grok once enabled. Do not silently remove gate, signup agreement, client-public-share consent or per-call paid AI approval. Future vertical: transfer consent at actual first external AI call, update controller/model/test, then remove the generic intake checkbox. No unsafe auto-pay/auto-share.
- No DB schema, migration, API call, Railway, private data or historical replay changes.

## New tests and acceptance

CI needs exact head Rails tests, browser tests, Security Audit; synthetic test verifies ActivityEvent from ProjectIntake appears with icon inside precise 22h band, 24 hours and month as typed item; owner/client dock tests verify no footer logout and header access. Visual acceptance only after user checks 1440/400/320 widths in a separate clean checkout and rebuilt CSS. Check date 2026-11-13 near 22:37, activity disclosure triangle, nav + header, month boundaries, request copy, owner headings. Each new test record is in ephemeral CI test DB only.

**Outstanding:** global demo/learner copy across every template and explicit checkbox design need another audited, access-aware slice. No claim complete removal. More event kinds (project milestones and user-created event types) need dedicated source-of-truth calendar projection; not done merely by icons. Production R1A PR #82 independently passed 6/6 and still remains Draft/unpublished with no backup; do not merge full PR #81 or run its many migrations.

## Next-chat continuity — 2026-11-23, verified after C2.4a

**Source baseline:** feature PR #81 at `aecbe5e7df02064af172ade51a6882de36420ae3`, draft/unmerged. Its exact-SHA PR GitHub Actions completed SUCCESS: Rails Calendar CI `45240914751`, Security Audit `45240914620` (two observed pull-request-triggered runs). This verifies automated checks of the **code SHA**, not owner browser, real AI usage, or a production deployment. A documentation-only commit after this paragraph needs its own checks before anyone calls its HEAD green.

**Owner terminal evidence, same day:** separate `~/rails_calendar_c24a_ui_review_20261123` detached worktree was created at `aecbe5e`; initial `npm ci` failed with `/home/gor/.asdf/shims/npm: ... exec: asdf: not found`. A later attempted guarded server launch in that worktree stopped on `Could not find puma-8.0.4 in locally installed gems`. The HTTP `200 OK` line belongs to the previous local server session; it does **not** prove the new worktree's assets were built or C2.4a visually passed. Owner stopped Puma at 22:35:50 +03. **Manual browser retest = NOT_TESTED, not PASS.**

**Read-only Railway inventory:** production project `rails-calendar-ai-workspace`, web `rails-calendar-ai-web` still sources `feat/client-owner-pilot-2026-11-13`, latest web deployment is `SLEEPING` from 2026-11-13; PostgreSQL 18 service has persistent `postgres-volume` (5000MB); web has no attached volume; no staged changes. No Railway action taken. Draft release PR #82 remains a separate release gate: `558cf80be59fd317aaaf18c41c4cd38e773f919c`, NOT DEPLOYED. Owner's no-backup preference is acknowledged but is not consent for a particular migration.

**Immediate owner-controlled F0/C2.4a unblock:** in the existing detached C2.4a worktree, verify exact HEAD and clean tracked status; restore local asdf binary discovery by including `$HOME/.asdf/bin` on PATH, select direct Ruby 3.4.13, then `BUNDLE_FROZEN=true bundle install` to install locked Puma 8.0.4, `npm ci && npm run build && npm run build:css`. Never alter Gemfile.lock, old checkout's dirty schema, or any database. Start only via the existing checked `script/rc0551f_c21c_local_grok_server.sh` with the named local review DB and explicit environment from the owner's previous run; script must independently pass its DB identity check. If any step fails, stop and return redacted stderr. First check updated UI **read-only** (month/day near 2026-11-13 22h, owner/client mobile nav, one-chevron disclosures, request copy) at 400px and 1440px, then send screenshots. No paid Grok submit, migration, media write or historical replay in this acceptance step.

**Next independent vertical only after screenshot gate:** complete controlled source-wide educational-copy audit and model-aware AI-consent relocation; do not remove provider data-transfer and billable-action safeguards as a visual cleanup.
