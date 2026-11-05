# RC-003 — supported Ruby/Rails upgrade and security audit

Recorded 2026-11-06. No Railway or production modifications.

## Confirmed runtime
- PR #2 base SHA: `bdfbeca0e494d2b44e1cf17698a63ee6da7e4baf`.
- Target: Ruby `3.4.12`; Rails `8.1.4.1`; Bundler `2.6.9`.
- Gemfile.lock was generated on GitHub Actions using bundle lock --update, then committed as SHA `c6fa4c8`.
- [CI #42126599149](https://github.com/TheGor-365/rails_calendar/actions/runs/42126599149): **SUCCESS**; 24 integration/model/controller tests and 71 assertions; 6 browser tests and 18 assertions; 0 failures/errors/skips. Isolated PostgreSQL service.
- Removes obsolete webdrivers gem; ChromeDriver installed in CI. No schema migration.
- Maintains `config.load_defaults 7.0` intentionally; upgrade of defaults remains separately reviewable.

## Security audit
- Dedicated `.github/workflows/security-audit.yml` checks ruby-advisory-db, Brakeman, and Yarn audit; **results must be checked before release signoff**.
- Scanner success does not prove absence of unknown vulnerabilities or correct production environment.

## Remaining blockers
- [ ] Manual review: PRs #1 / #2 / #3, suitable merge order after approval.
- [ ] Review security audit findings, fix actual vulnerabilities, rerun checks.
- [ ] Move to reviewed Rails 8.1 framework defaults incrementally, test with existing data.
- [ ] Login rate limiting, HTTPS/secure session cookies, deployed secrets, security headers.
- [ ] Verify public consultations contain no client personal details.
- [ ] Staging DB backup/rollback; migration + browser smoke; no public production deploy without confirmation.
- [ ] Consider dependency update automation (Dependabot) after baseline stable.

## Official source references
- https://rubyonrails.org/maintenance
- https://rubyonrails.org/2026/11/4/Rails-8.0.5.2-and-8.1.4.1-have-been-released
- https://guides.rubyonrails.org/upgrading_ruby_on_rails.html
- https://www.ruby-lang.org/en/downloads/branches/
