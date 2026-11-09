# RC-032 — Owner account bootstrap (local development only)

This implements first-owner signup with bcrypt-hashed passwords, revocable
PostgreSQL-backed login sessions, eight-hour session expiry and database-backed
per-IP attempt limits. The old Railway administrator login remains unchanged.

## Security boundaries

- `/sign_up` GET/POST works **only** in Rails development/test, from a loopback
  client, with `RC_LOCAL_OWNER_SIGNUP=true`, and only until the first owner
  exists. **Production is closed, even if the flag is accidentally enabled.**
- A PostgreSQL transaction-scoped advisory lock prevents concurrent bootstrap
  owners. This is account bootstrap, **not** public multi-tenant registration.
- Owner login `/sign_in` works for an already-created owner. `/sign_out`
  revokes the DB session. The legacy admin login `/admin/login` remains usable.
- Existing consultation and intake records are still global legacy demo data;
  client accounts and tenant access are **not** enabled. Email verification,
  invitation-only client onboarding, recovery emails and tenant ownership
  are future security gates before real customer data.
- Never put owner credentials, cookies, database URLs or password reset tokens
  in Git or screenshots.

## Local setup (existing isolated worktree only)

1. Verify the worktree `~/rails_calendar_ai_workspace_dev` and the isolated
   PostgreSQL identity `rails_calendar_ai_dev_20261108 / rails_ai_dev` on `127.0.0.1:55415`.
2. Set `RC_LOCAL_OWNER_SIGNUP=true` only in the private local env file.
3. Run `bundle install` and **after verifying the DB connection**
   `bin/rails db:migrate` in development. Rebuild frontend if needed.
4. Restart localhost Rails on `127.0.0.1:3015`. Use `/sign_up` exactly once,
   then `/sign_in` to log in. Registration should become HTTP 404 thereafter.
5. Run integration tests in an independently verified test-only DB; do not
   use the legacy `ruby_calendar_test` or production DB.

No Railway release is authorized by this local change. Preserve PR #31 and the
existing Railway web+Postgres as-is pending CI/security and a DB backup plan.
