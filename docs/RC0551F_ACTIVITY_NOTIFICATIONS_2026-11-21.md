# Rails Calendar — owner notification inbox handoff (2026-11-21)

## Verified baseline before this slice
User's isolated Linux build completed successfully. Both isolated development and test databases migrated `CreateActivityEvents`; reported tests: **47 runs, 880 assertions, 0 failures, 0 errors, 0 skips** at `b4cbd02`. The newly added notification changes have not yet been locally executed.

## New implementation
- `activity_event_reads` join table: `activity_event_id`, `owner_user_id`, `read_at`, PostgreSQL uniqueness on owner/event and FK constraints. No email, third-party API, extra AI calls or duplicate event payloads.
- `Activity::Inbox`: unread count from current owner workspace and existing read receipts, idempotent insert on read, bounded 500-event batch for mark-all.
- `OwnerNotificationsController`: owner-only index with `all`/`unread` tabs, POST read-one-and-open, POST mark-all. GET never changes read state; owner scope checked for every operation.
- `/workspace/notifications`, `/workspace/notifications/:id/read`, `/workspace/notifications/read_all`.
- White Atlas notification cards with status, timestamps, icons, links, unread accents. RU/EN/HY/ES.
- Desktop navigation badge, workspace card, owner cabinet shortcut usable on mobile. Counter reflects persisted activity events minus read receipts.
- Regression tests added to E2 controller suite for unread counts, read idempotency, cross-tenant ACL, POST vs GET, mark-all.
- Existing inbox message-unread state is separate and unchanged. Marking an activity notification read does **not** approve a client brief/spec or consume a one-time link.
- Protected original port 3001, production Railway and paid Grok untouched.

## Validation next
1. Review local `git status --short`. Do not overwrite modified `db/schema.rb`. Fast-forward pull to current feature branch, build JS/CSS.
2. Verify exact existing UNIX-socket review DB identities and empty `DATABASE_URL`; migrate only `rails_calendar_rc0551f_c21b_review_20261117` (dev) and `rails_calendar_rc0551f_e2_test_20261119` (test).
3. Run the E2 invitation, consultations and pages controller tests with `RC_GROK_ENABLED=false` and `PARALLEL_WORKERS=1`; inspect exact GitHub CI SHA.
4. Browser: open notification inbox from top nav or owner cabinet; issue a new invitation; confirm unread counter changes; click read/open to view source; return and verify count decrements, persists after reload. Log in as distinct owner and verify nothing crosses workspace scope.
5. Do not claim mail/browser push or third-party notification delivery; those are not implemented.

## Follow-on
- Explicit event importance and category policies; suppress noise for self-actions as a user-configurable preference.
- Durable transactional outbox and platform/email delivery only after the user approves channels and sender policy.
- Expand events and artifact registry to attachments, AI conversation turns and service versions. Source-aware search and previews, no duplicate canonical content.
- Event-led state in month/day/hour and project dashboards.
