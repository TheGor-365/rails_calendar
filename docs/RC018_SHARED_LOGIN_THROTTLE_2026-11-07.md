# RC-018 — Shared PostgreSQL administrator login throttle

**Date:** 2026-11-07. **Status:** Code CI+Security SUCCESS on SHA `39d9e44be2c45ef08945967abd0385c27f48451b`; local/staging migration and owner QA pending.  
**Parent:** [RC-017 privacy gate](https://github.com/TheGor-365/rails_calendar/pull/18).

## Risk addressed

Earlier sessions controller used `LOGIN_RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new` with Rails rate_limit to five login attempts per minute by remote IP. Its counters were private to one Rails process; scaling to multiple web instances could dilute the limit. Generic RedisCacheStore is not a safe drop-in *authentication* gate: Rails documentation states Redis cache operations may silently fall back to misses on outage. An unverified/paid new Redis service is not provisioned.

## Decision

Use the already necessary **PostgreSQL** database as the shared, authoritative limiter. The app does not require Redis. Implement additive `admin_login_windows` table and an atomic `INSERT ... ON CONFLICT DO UPDATE ... RETURNING attempts`. All successful and failed authentication submissions count; the sixth within a **fixed** 60-second window returns HTTP **429**, regardless of Puma worker/instance. Do not hit this table on any public calendar read route.

- Store `client_digest` as HMAC-SHA256 of `request.remote_ip` with Rails secret, **never raw IP, password, or username**.
- Derive production window from PostgreSQL `clock_timestamp()`, not individual Rails process clocks. Tests can supply a deterministic `now`.
- Two unique columns `(client_digest, window_start_epoch)` guarantee concurrency-safe increments. Index by epoch for retention.
- On any ActiveRecord database error, login requests fail closed with **503**; no fallback memory cache. Error logs contain exception class only.
- Optional pruning after 2 days via `AdminLoginWindow.prune_expired!` (must be invoked by a separately configured monitored job). Do not delete local records during this PR.
- The explicit login limiter may restrict clients behind a shared reverse-proxy IP. Before production, check `request.remote_ip` and proxy trust configuration. Never trust arbitrary client-supplied `X-Forwarded-For`.

## Migration / deployment contract

**Additive migration** `db/migrate/20261107123000_create_admin_login_windows.rb`; `consultations` unchanged. Requires staging and local **database backup before migrate**, consistent schema and rollback verification. If table is missing, admin login must fail, not silently bypass throttling. Never run production migration or change Railway without an owner release decision.

Production dependency remains the existing PostgreSQL URL. No new cloud subscription or paid integration.

## Tests and evidence

- Existing session tests: first five attempts 401, sixth 429, successful login still works on fresh bucket.
- New model tests: atomic shared SQL counter, distinct IPs/windows, non-plaintext digest, retention.
- All existing admin ACL/session/CSRF-related tests remain. Manual testing of the proxy, multiple actual Railway instances, and operational 503 on DB outage still requires staging.
- RC-017 private mode manually verified by owner in Chrome incognito: anonymous `/` redirected to `/admin/login` with appropriate alert.
- Consultation `#3` and `#4` remain in the owner's local DB; **do not delete or recreate** either. Earlier `#2` was a disposable demo, and owner waived recovery.

## Remaining release gates

1. **PASS** [CI run #42373571723](https://github.com/TheGor-365/rails_calendar/actions/runs/42373571723) and [Security run #42373571745](https://github.com/TheGor-365/rails_calendar/actions/runs/42373571745) on code SHA `39d9e44`: 71 Rails tests / 485 assertions + 15 Chrome tests / 172 assertions = 86 tests / 657 assertions, 0 failures/errors/skips. Isolated CI migration/schema checked.
2. Separate backup + staging schema migration, smoke and restore test.
3. Privacy ownership/tenant scope before real client data, per-client record ACL and secrets review.
4. Decision on UTC + Armenia/client time zone display (see ADR-001); no silent conversion.
5. Full stacked PR ancestry review (#4 is superseded); no merge/deploy without explicit gate.

**Next:** after RC-018 security acceptance, work P1 incremental schedule usability (exact duration, search/filter, validated admin actions), then the narrow Rails AI Intake spec/approval workflow.
