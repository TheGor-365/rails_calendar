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

## RC-003 supported runtime (Draft PR #4)

- Ruby **3.4.12**, Rails **8.1.4.1** and refreshed Ruby/JavaScript lockfiles are on the RC-003 branch for compatibility and security testing only.
- Read [isolated Linux Mint local setup on port 3005](docs/RC-003_LOCAL_RUN_3005.md) before running alongside other Rails projects.
- This is not a deploy approval; [CI](https://github.com/TheGor-365/rails_calendar/actions) and both dependency audits must be reviewed before merge.

## Remaining release blockers

- PostgreSQL, Turbo/Stimulus, Bootstrap, esbuild/Sass, Simple Calendar remain in the existing architecture.
- Existing database config is local-development-oriented; production credentials,
  DB connectivity, backup/rollback, HTTPS and secure session cookies require review.
- Login attempt rate limiting, dependency/security audits, legacy invalid data
  assessment, and staging/browser smoke validation are release gates.
- The repository is not production-ready merely because CI passes.

## Local development (isolated DB only)

Install Ruby 3.4.12, a compatible Bundler, PostgreSQL and Node/Yarn in this **project only**.
Follow [local instructions](docs/RC-003_LOCAL_RUN_3005.md), then run `RAILS_CALENDAR_PORT=3005 bin/dev`.
Other Rails apps can keep their existing ports.
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
