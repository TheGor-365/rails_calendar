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