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

## Legacy baseline and remaining release blockers

- Ruby 3.1.2 / Rails 7.0.4.1 are end-of-life. Upgrade before public production.
- PostgreSQL, Turbo/Stimulus, Bootstrap, esbuild/Sass, simple_calendar 2.4.3.
- Existing database config is local-development-oriented; production credentials,
  DB connectivity, backup/rollback, HTTPS and secure session cookies require review.
- Login attempt rate limiting, dependency/security audits, legacy invalid data
  assessment, and staging/browser smoke validation are release gates.
- The repository is not production-ready merely because CI passes.

## Local development (isolated DB only)

Install the pinned Ruby version, compatible Bundler, PostgreSQL and Node/Yarn.
Then install dependencies, prepare a development DB and run bin/dev.
Do not connect a test instance to production data.

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
