# RC055.0b — Client clarification reply + persistent unread replay
Date: 2026-11-15. Stacked on Draft PR #60 exact base SHA `d68f55bbd08cf8a1d2a4138d59f1189527c693a0`.

## Scope
- On the existing fictional client request detail, display its saved conversation (up to 20 records; pilot currently limits client turns to 8) with role markers, UTC times and escaped multiline text.
- Verified client can send an additional clarification **only on their own request** while `ClientRequestPilot.enabled?` is true. Server requires a 32-hex client submission key, a nonempty 1–1200-char body, and respects existing `ProjectIntake::MAX_CLIENT_MESSAGES=8` including original request. Invalid submission stays on the form with an error and no data created.
- Atomic request row lock plus a unique DB index on `(project_intake_id,client_submission_key)` prevents double-click/replay from creating two messages; request token is newly issued per show page and preserved across validation errors. A replay is acknowledged but never creates a duplicate, even at the cap.
- Database migration adds **nullable** client submission key, partial unique index. No old conversation is rekeyed or deleted. Model allows null for historical entries.
- Saving a message automatically reactivates existing RC055.0 owner unread count on the next server-rendered owner page. No new notification/polling/AI backend, no assistant-generated auto-response, no changes to project status or spec review/approval.
- UI remains White Atlas, with safety reminder and 4 locales. Reply is not acceptance of an offer or quote.

## Security and rollout
- No contact data, credentials or secrets. No cross-account or owner reply path. Client form CSRF remains Rails default.
- Independent backup + isolated restore gate required before applying this second migration to the actual local DB; the previous RC055 backup predates the last migration. Check uncommitted `db/schema.rb` and retain all snapshots. Do not use `git restore`/stash/reset without inspecting why it is dirty.
- Exact-SHA Rails/Chrome/Security CI, local client→owner→client→owner scenario, 320/390 mobile, and successful permission tests before release.
- Draft PR only. No merge, Railway or production actions.
