# RC-039 Slice E — accessible synthetic board and safe conflict recovery

**Test-only owner UI improvement, not production task management.** This slice addresses two concrete UX/safety gaps in Slice D without adding user data, migrations, providers, task fields, scripts, routes or external services.

## 409 and 422 recovery contract

\`Studio::SyntheticProjectCardsController\` preserves Slice C's JSON contract unchanged. On HTML-only \`transition_preview_card\`, an optimistic-lock conflict (HTTP **409**) now regenerates the live, owner-scoped board rather than returning plain text. The page shows a visible \`role="alert"\` notice, a **Reload current board** link and the **current** persisted state/version; it never echoes stale form inputs or processes an automatic retry. Invalid state transitions or fictional card names (HTTP **422**) follow the same redacted HTML path. A failed second authorization check returns 404 rather than displaying a board. A successful form still uses POST/redirect/GET and the existing database transaction + append-only audit.

## Accessibility and visual contract

- Four named lane sections use \`aria-labelledby\` pointing to real visible \`h2\` elements; every candidate card has a stable heading \`id\`.
- Each prerequisite \`summary\` and create/move control has \`aria-describedby\` for its card heading, so repeated actions retain context for assistive technology.
- Failed submissions render an \`aria-live="assertive"\` alert with a focus-visible, minimum-44px refresh link. The HTML still uses ordinary CSRF-protected, keyboard-operable forms, not drag-and-drop or synthetic client permissions.
- No project/client names, raw sources, generated documents, external AI or financial data are returned in error pages.

## Acceptance and limits

- HTTP integration tests check no new audit rows on conflict, refreshed current version, reloaded safe board, no forged source reflection, unchanged 409/422 semantics and no client approval.
- Chrome tests use Enter on a disclosure widget at a 320px CSS viewport; the earlier 320/390/430px workflow test remains.
- Run targeted HTTP, full Rails suite and Chrome system suite using isolated \`ruby_calendar_test\`, plus exact-head push/PR CI and Security Audit.
- Manual screen-reader audit, keyboard-only end-to-end paths, contrast review on actual devices, real workspace client consent, encrypted source storage, trustworthy scanning, and production release remain **open gates**.
- No \`git reset\`, \`git clean\`, \`db:reset\`, \`db:drop\`, merge or deployment. Keep detached QA worktree \`db/schema.rb\` modified and uncommitted.

A *functional* Project Hub with real human tasks, assignment, comments, due dates, project-specific calendar and rich Kanban requires a separately reviewed schema and access-control design. This slice deliberately does not impersonate that release.
