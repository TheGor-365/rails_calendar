# RC-012 — Mobile calendar feature parity (2026-11-06)

## Incident and verified user report

At 430 CSS px in Chrome device emulation the monthly calendar retained an 810px table minimum width, showing only Monday–Thursday without horizontal dragging. Events on Saturday 7 and Sunday 8 November were not initially discoverable. Day cells were technically anchors, but lacked a sufficient mobile affordance and event previews remained off-screen. User-provided screenshots are the evidence; this is a UX/reachability defect, not missing consultation records.

## Permanent product principle

**Mobile functionality parity is an acceptance requirement, not an optional adaptation.** Every action available on desktop must have a clearly visible, keyboard-accessible and touch-usable mobile path. Reflow may differ, but mobile must preserve reachable destinations, meaningful labels, state/feedback, and server-enforced authorization. Never ship a seven-day calendar where events require discovering hidden horizontal scrolling.

## Implementation

- Responsive seven-column monthly grid at widths <=767.98px; all Monday–Sunday dates visible simultaneously at 320, 390 and 430 CSS px.
- Each date remains a distinct full-cell link to `/calendar/day`, with a visible count badge for busy dates and highlight for today. Month previous/next and Today remain present.
- Desktop event previews remain unchanged. Mobile shows a separate **Events in month** agenda below the grid, grouping days with a direct date link, individual links to first two events and a `View all N events` link to the full day if busy. No nested anchors and no JS click handlers. The same destinations are reachable on both layouts.
- The independent time-axis anchor gets a full-height touch target even when a long event overlays the right-hand hour bands.
- Existing public read/admin-only mutation policy preserved. No schema migration, secret, database or production deployment.

## Acceptance matrix / tests

| Scenario | Evidence |
| --- | --- |
| All 7 day columns visible at 320/390/430 without body overflow | Chrome system test: screen width + Monday and Sunday bounding rect |
| Mobile day → 24h view | Chrome system test |
| Mobile event shortcut → consultation detail | Chrome system test |
| Mobile left time axis → interval detail | Chrome system test |
| Desktop month event links unchanged | Chrome system test |
| Busy day 2 previews + all-events entry | Rails integration test |
| Public GET/admin-only mutations | Existing integration/system tests |
| Manual device QA (320/390/430 + touch/keyboard) | **Awaiting owner screenshots** |

## Safe local QA

1. After final head CI and Security success, stop only this repository's port 3005 process using Ctrl+C.
2. With clean tracked worktree, fetch `fix/rc012-mobile-calendar-parity-2026-11-06`, switch and run `bash bin/run-calendar-3005`. Never remove `.tool-versions` or `vendor/bundle/`, force-reset, or kill all Ruby processes.
3. Open November 2026 at 320/390/430px, check all seven weekdays and Saturday/Sunday events, tap date and the independent event in the mobile agenda, then tap time axis in day schedule. Verify keyboard, visible focus, scrolling, and admin-only controls.

## Release safeguards

Draft stacked on Draft PR #11, which is stacked on #10 and earlier. Do not merge directly to `main`, deploy Railway, create new databases or publish promotional claims until UI acceptance, stacked PR review and release gates. Preserve all other projects and user data.

## Evidence links

- Repository: https://github.com/TheGor-365/rails_calendar
- RC-011: https://github.com/TheGor-365/rails_calendar/pull/11
- Notion RC-011 checkpoint: https://app.notion.com/p/4102cdc8e76581eaa500d6aab39996a6
