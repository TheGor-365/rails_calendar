# RC-004 — Calendar UX, accessible forms, mobile review

Status: Draft candidate; separate from admin authorization and runtime security.
Based on RC-006 Draft PR #5 (commit `195e2ad...`). **No main or Railway deployment.**

## Scope delivered in candidate branch
1. Month calendar: semantic navigation with previous/next links, descriptive accessible labels and month heading; data table with a caption and seven weekday column headers; real `<time datetime>` for each day.
2. Readable narrow-screen display: horizontal table scrolling in a keyboard-focusable region. Seven columns retain a functional minimum width instead of squeezing unreadable cards.
3. Calendar consultation entries: clear title, start time, description preview, and full detail link; display time-zone is shown without changing database timestamps.
4. Forms: consistent Bootstrap styling, `required` on the three required values, explicit time-zone guidance, `aria-invalid` on invalid controls, accessible validation summary. Existing server-side validations remain authoritative.
5. List and details: semantic entries, explicit timestamp elements, graceful handling of empty lists and legacy NULL fields.
6. Regression tests for semantic navigation, month selection, form fields and invalid start/end validation.

## Acceptance before release
- GitHub Actions model/controller/integration + browser tests on this exact SHA.
- Security audit on this exact SHA. Runtime/library CSS deprecation warnings are independent; avoid silent broad dependency changes in this PR.
- Local desktop + mobile manual screenshots (keyboard, 375 px viewport, horizontal calendar scroll, admin form errors) and feedback. No screenshots are claimed until supplied.
- Admin login throttle and private CRUD routes must remain unchanged. Do not publish client/PII records from the calendar.
- No production deploy before backup/rollback, shared rate-limit cache and human review.
