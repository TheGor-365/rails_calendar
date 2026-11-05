# Rails Calendar

A small Ruby on Rails demonstration application for displaying and managing consultations with [Simple Calendar](https://github.com/excid3/simple_calendar).

## Current legacy baseline

- Ruby **3.1.2**, Rails **7.0.4.1** (both release series are end-of-life)
- PostgreSQL, Turbo/Stimulus, Bootstrap, esbuild/Sass
- `simple_calendar` **2.4.3**
- Stored events: title, description, start/end timestamps

**Security warning:** The existing consultations CRUD does **not** implement authentication or authorization. Do not expose this repository to a public production audience until an appropriate access-control policy is implemented and tested. The pull request that adds validations/calendar tests is **not** an authorization fix.

## Local development (isolated development database)

1. Install Ruby 3.1.2 and Bundler 2.3.7 for this historical checkout; plan a migration to supported Ruby/Rails before production.
2. Install PostgreSQL and Node.js/Yarn compatible with the pinned dependencies.
3. Run:

```bash
bundle install
yarn install --frozen-lockfile
bin/rails db:prepare
bin/dev
```

Open http://localhost:3000.

Current `config/database.yml` expects PostgreSQL on `localhost:5432` with the `postgres` role; use an **isolated local database**. Do not use the database config as-is for Railway/production.

## Tests

```bash
RAILS_ENV=test bin/rails db:prepare
RAILS_ENV=test bin/rails test
```

The controller/model test suite does not replace real browser system tests. CI is intended to run the non-browser tests first. A verified successful CI run and a deployed instance must be linked before describing the project as release-ready.

## Delivery checklist

- [ ] Agree public/private data access and consultation editing rules.
- [ ] Add authorization tests and enforce the agreed policy.
- [ ] Upgrade end-of-life Ruby/Rails and audit dependency vulnerabilities.
- [ ] Verify model/controller/system tests and CI on a clean environment.
- [ ] Configure production PostgreSQL via safe environment variables, TLS, secrets and backup/rollback.
- [ ] Perform mobile/desktop smoke tests and capture evidence.

Engineering tracking: [ClickUp Rails Calendar](https://app.clickup.com/t/z8rp3ffu75) / [RC-001 audit](https://app.clickup.com/t/z8rp3ffu82). The app is a demo/learning project, **not** a verified paid client deployment.
