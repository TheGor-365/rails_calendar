# RC-003 — Ruby/Rails upgrade and dependency security gate

Date: 2026-11-06
Scope: educational Rails Calendar only. No production/Railway operations.

## Source baseline
- PR #2: https://github.com/TheGor-365/rails_calendar/pull/2
- Last known green baseline: bdfbeca0e494d2b44e1cf17698a63ee6da7e4baf
- Ruby 3.1.2 + Rails 7.0.4.1 (unsupported).
- CI: 30 tests, 82 assertions, 0 errors in isolated GitHub Actions.

## Target
- Ruby 3.4.12 (published 2026-10-23).
- Rails 8.1.4.1 (security release 2026-11-04).
- Preserve existing data schema and public read / admin write policy.
- Remove obsolete webdrivers gem, continue selenium+ChromeDriver system testing.
- Continue using config.load_defaults 7.0 until staged defaults migration is reviewed.
- No data schema migration, irreversible change or production rollout in this PR.

## Review gates (do not mark complete without evidence)
- [ ] Produce reproducible Gemfile.lock with bundler and commit it.
- [ ] CI PostgreSQL tests pass on locked bundle.
- [ ] Browser system tests pass (anonymous read/admin sign-in and CRUD).
- [ ] Bundler dependency advisory audit, JavaScript dependency audit.
- [ ] Review deprecations and regenerate framework defaults separately, with diffs.
- [ ] Check production session transport, CSRF, brute-force throttling, secrets, public data privacy.
- [ ] Verify clean staging boot, migration compatibility, manual smoke tests.
- [ ] Security review and human approval before merging PR #1/#2/#3 or deploying.

## Source references
- https://rubyonrails.org/maintenance
- https://rubyonrails.org/2026/11/4/Rails-8.0.5.2-and-8.1.4.1-have-been-released
- https://guides.rubyonrails.org/upgrading_ruby_on_rails.html
- https://www.ruby-lang.org/en/downloads/branches/
