# RC055.0c — opt-in long sessions for local browser QA (2026-11-15)

Stacked on Draft PR #61 `cdac632e6c3e45cf96bd5348ac84bcd3f4dce1a6`. **No migration, no account resets, no production change.**

## Motivation

Both owner and verified-client `UserSession` rows expire after eight hours. The default encrypted Rails session cookie is non-persistent; Chrome Incognito also clears its entire cookie jar on closing the last Incognito window.

## Opt-in behavior

- Development environment **only** when `RC_LOCAL_LONG_SESSIONS=true` is loaded **before server boot**:
  - New owner and verified client DB sessions have fixed `expires_at` 14 days after sign-in, still revocable by logout.
  - Rails encrypted, host-only, HttpOnly, SameSite=Lax cookie gets a matching `expire_after: 14.days` so regular Chrome profiles survive browser restarts. No sliding extension.
  - Existing sessions are **not** extended; sign in once after restarting the server.
  - No new privilege, login bypass, password recovery, or tenant scope.
- Every other case (all production/test/staging and non-opted-in development) keeps **8 hours** and a session-only cookie.
- Legacy `AdminAuthentication` is **always eight hours**.
- Chrome Incognito still deletes cookies when all Incognito windows close. Use a separate normal Chrome profile **only for local fictional client QA** if persistent login across restarts is desired.
- Do not use this flag in any deployed app or with real customer data. Do not paste private env contents, passwords, cookies or session tokens into chats.

## Local QA

1. Switch to this branch only when `git status` is clean. The preview DB has already been migrated through RC055.0b; this change adds **no migration**.
2. In the private preview startup env file `~/.config/rails-calendar/preview-3012.env`, set `RC_LOCAL_LONG_SESSIONS=true`. Restart **the existing** preview Rails server on localhost :3012 so both cookie initializer and login handler load the setting.
3. Verify `RAILS_ENV=development bin/rails runner 'puts "ENABLED=#{RcLocalSessionPolicy.enabled?} LIFETIME_HOURS=#{RcLocalSessionPolicy.session_lifetime.to_i / 3600}"'` returns `ENABLED=true LIFETIME_HOURS=336`. New login is required; existing 8-hour DB sessions are not prolonged.
4. Use a separate normal Chrome user profile for local fictional client; don't use the owner profile. Login once with existing `client-preview@example.test` account. Then test RC055.0b reply `/client/requests/2` → owner inbox count 1 → owner opens detail and count 0.
5. CI Rails/Chrome/Security; no deploy or merge authorization.
