# Rails Calendar

A Ruby on Rails educational/demo app for publicly browsing consultations with Simple Calendar.

## Security contract (RC-002)

- Public: GET /, GET /consultations, GET /consultations/:id.
- Administrator only: new/create/edit/update/destroy consultation routes.
- The admin sign-in and sign-out endpoints are /admin/login and /admin/logout.
- There is no public account registration, and no users table migration.
- The application denies admin access if either server-side credential is absent.
- Admin sessions expire after eight hours and are invalidated by credential rotation.
- Never include real consultation PII in publicly exposed demo records.

## Required admin secrets (outside source control)

Supply RAILS_CALENDAR_ADMIN_USERNAME and RAILS_CALENDAR_ADMIN_PASSWORD via
the deployment secret manager. Use a unique, long random password; never commit
credentials, put them in client-side JavaScript, or paste them into issues.
Administrators sign in via /admin/login. The application does not seed an admin
password or automatically generate one.

## Runtime upgrade in progress (RC-003) and remaining release blockers

- Upgrade candidate: Ruby 3.4.12 / Rails 8.1.4.1, locked on the RC-003 draft branch and passed isolated CI; PR #3 is not merged.
- PostgreSQL, Turbo/Stimulus, Bootstrap, esbuild/Sass, simple_calendar 2.4.3.
- Local/test database names are isolated; production requires an explicit `DATABASE_URL`.
  DB connectivity, backup/rollback, HTTPS and secure session cookies still require review.
- Login attempt rate limiting, dependency/security audits, legacy invalid data
  assessment, and staging/browser smoke validation are release gates.
- The repository is not production-ready merely because CI passes. See Draft PR #3 and the security audit workflow.

## Local development (isolated DB only)

Install the pinned Ruby version, compatible Bundler, PostgreSQL and Node/Yarn.
Follow [isolated Linux Mint setup](docs/RC003_LOCAL_RUN_3005.md) to use this app on **127.0.0.1:3005** alongside other Rails projects. Run only this project's development/test DB commands; never connect to a production database.

## Automated tests

Run RAILS_ENV=test bin/rails db:prepare and RAILS_ENV=test bin/rails test.
Run RAILS_ENV=test bin/rails test:system for headless/browser coverage.
The test suite uses explicitly named test-only credentials in test/test_helper.rb;
those are intentionally not production credentials.

## Tracking

- ClickUp RC-001: https://app.clickup.com/t/z8rp3ffu82
- ClickUp RC-002: https://app.clickup.com/t/z8rp3ffu83
- Baseline Draft PR #1: https://github.com/TheGor-365/rails_calendar/pull/1

Educational case only; not a verified paid client deployment.

## RC-003 runtime and dependency audit

- [Draft PR #3](https://github.com/TheGor-365/rails_calendar/pull/3) migrates to patched Ruby 3.4.12 / Rails 8.1.4.1 and resolves Ruby/JS dependencies.
- [Runtime CI](https://github.com/TheGor-365/rails_calendar/actions/runs/42128427245) and [Security audit](https://github.com/TheGor-365/rails_calendar/actions/runs/42128427372) passed before final cleanup. See [RC-003 checkpoint](docs/RC003_RUNTIME_UPGRADE.md) for remaining release blockers.
- Remains an **unmerged educational demo**, not a verified production service.
