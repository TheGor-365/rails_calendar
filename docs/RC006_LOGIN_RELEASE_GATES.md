# RC-006 — Admin login and release-security gates

2026-11-06. Draft only, stacked on [RC-003 PR #3](https://github.com/TheGor-365/rails_calendar/pull/3).

## Implemented in this branch
- Rails 8 built-in request rate limit on `POST /admin/login`: **5 attempts per minute per IP**, HTTP 429 on sixth attempt. The public calendar is unaffected.
- Uses a bounded, per-process `ActiveSupport::Cache::MemoryStore` to make the check reproducible in development/tests. **This store does not aggregate counters across servers/workers and is not approved for a horizontally scaled public deployment.**
- Integration test: 5 failed logins -> 429 on a valid sixth request; anonymous public calendar still available and admin forms still restricted.
- Production configuration enables `config.force_ssl = true` (redirect/secure cookie/HSTS). Staging must verify proxy headers, HTTPS termination, browser cookies, and redirect loops before deployment.

## Blocking release gates
1. Configure **shared, non-null rate-limit cache** if staging/public environment has more than one process/instance; re-test under intended topology. Do not claim multi-worker brute-force protection from the MemoryStore.
2. Supply private admin credentials and Rails secret via deployment secret manager; no credentials in repository, screenshots, ClickUp, Notion, or logs.
3. Human review of stacked PRs #1/#2/#3 and this PR; review Rails 8 defaults, CSRF and session cookies; CI model/controller/browser suite and audit must pass.
4. Read-only inspection of potential PII in any existing consultations before publishing the calendar. Test with synthetic records only.
5. Test production `DATABASE_URL`, backup/restore plan, migrations, rollback, Railway pricing/resources, staging HTTP + manual UI smoke with explicit user approval.
6. Do not merge to main or deploy directly from this Draft PR.
