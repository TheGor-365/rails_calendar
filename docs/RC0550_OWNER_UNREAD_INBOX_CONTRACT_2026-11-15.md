# RC055.0 — persistent owner unread client intake indicator
Date: 2026-11-15. Based on Draft PR #59, exact SHA `1adc935a4ec1ebb57ba01f6612e65e58960dea14`.

## Problem and constraints
The owner inbox displayed all intakes but did not record whether a client-created request was opened. Status `interviewing` is not unread. A client-facing request and legacy owner synthetic demo have different sources and must not be conflated.

## Contract
- `owner_intake_read_states` belongs to a DB owner account, a client-associated intake and a client-authored message cursor. Exactly one receipt per owner/intake. Foreign keys, uniqueness, model validation, first/last seen timestamps. Old rows remain unchanged; no backfill marks old client requests read.
- `OwnerIntakeInbox.unread_for(owner:)` counts distinct **client-associated requests** with at least one client-authored message ID greater than the persisted cursor. Assistant messages, owner-only synthetic intakes and spec/version transitions do not increment the count. Multiple messages on one intake count as one request.
- `ProjectIntakesController#show` advances only the displayed client-message cursor when `owner_signed_in?` (DB-backed role owner); legacy administrator and clients never write receipts. Inbox index remains read-only.
- Transaction-safe `create_or_find_by!` and row-locked monotonic updates prevent a stale tab from reversing the cursor. A later client message will mark the intake unread again.
- The current view fetches at most 20 oldest messages. Only those actually displayed can become read; future pagination/backfilling latest messages must not mark undisplayed messages read.
- Desktop owner navigation and compact mobile owner dock show a number, scoped unread inbox rows show a dot and `New`. No fake notifications; 0 suppresses the badge; visible number caps at 99+, accessible label exposes the exact count.
- No trusted email/push delivery, no job background watcher and no live Turbo broadcast in this phase. Count refreshes on new server-rendered page loads; the next real-time phase may add Turbo Streams.

## Single-owner privacy limit
The current `ProjectIntake` lacks `owner_user_id`/workspace assignment. Consequently RC055.0 models the existing **single-provider pilot**; do not enable a multi-provider tenant launch until tenant ownership is added and scoped in models, queries, and ACL. This release does not claim per-provider isolation in a multi-provider system.

## Database and release gates
- Adds a single table `owner_intake_read_states`; no destructive schema change, no existing row migration, no AI spend or profile changes.
- CI migration runs only against isolated test DB. User's local `rails_calendar_mvp_preview_20261112` must first be backed up using local socket `/var/run/postgresql`, owner `gor`; record actual dump path + SHA-256 and test isolated restore with a compatible client if feasible. Never copy app secrets into chat.
- After backup + exact-SHA Rails/Chrome/Security PASS: local source pull and migration on **explicitly verified development DB only**. Verify `db:migrate:status`, owner login, 2 client demo records and new unread count; test mobile 390/320, client isolated access, old legacy admin.
- No Railway migration/merge/deploy or production data changes. Existing owner-approved professional profile v1, user sessions, encrypted credentials and draft PR stack remain untouched.

## Acceptance matrix
1. Two new client requests: badge 2; visiting inbox leaves 2; opening request #1 leaves 1; opening #2 leaves 0.
2. New client-authored message after read: badge becomes 1 on next page load; a stale browser tab cannot clear a newer unread turn.
3. Assistant messages, owner-created fake intakes, unreadless cases are never counted.
4. Client/guest cannot read owner inbox or mark receipts; legacy admin does not consume a DB owner's read state.
5. Refresh persists after session/browser restart; no auto-credit/acceptance/contract transition.
6. 1440/390/320, keyboard and screenreader labels; no xAI calls.
