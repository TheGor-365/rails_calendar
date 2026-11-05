# RC-003 — supported runtime and dependency security audit

Checkpoint: 2026-11-06. Scope: isolated [Draft PR #3](https://github.com/TheGor-365/rails_calendar/pull/3), based on unmerged [Draft PR #2](https://github.com/TheGor-365/rails_calendar/pull/2). No merge or deployment.

## Final resolved dependencies
- Ruby 3.4.12; Rails 8.1.4.1; Bundler 2.6.9.
- Puma 8.0.2; `pg` 1.7.0; Sass 1.107.1; esbuild 0.28.2; `@hotwired/turbo-rails` 8.0.23.
- Committed reproducible `Gemfile.lock` and `yarn.lock`, not a CI-only ephemeral resolution.
- Removed legacy `webdrivers` and use explicit ChromeDriver in CI.
- Kept `config.load_defaults 7.0` during migration: next phase should review each default change before switching to Rails 8.1 defaults.
- No database schema changes or production resources touched.

## Verified evidence (before final cleanup commit)
- [Ruby and browser CI #42128427245](https://github.com/TheGor-365/rails_calendar/actions/runs/42128427245): **SUCCESS**, 24 model/controller/integration tests / 71 assertions + 6 browser system tests / 18 assertions; 0 failures, errors or skips.
- [Security audit #42128427372](https://github.com/TheGor-365/rails_calendar/actions/runs/42128427372): **SUCCESS**; `bundler-audit` 0 known vulnerabilities, Brakeman 0 warnings, Yarn audit `info=0 low=0 moderate=0 high=0 critical=0`.
- Remediated in PR: 2 High Puma advisories (CVE-2026-47736/47737) and 9 outdated Sass/transitive JS advisories, followed by 2 remaining advisory findings in esbuild (Moderate) and Turbo (Low); final scan now zero.
- The release candidate is safe to **review**, not automatically safe for public traffic. Scanner databases evolve.

## Release blockers (remain OPEN)
- [ ] Human security review PR #1 / PR #2 / PR #3 and approved merge sequence.
- [ ] Review Rails framework defaults and warnings; controlled migration across stored consultation data; no destructive database operations.
- [ ] Login rate limiting and brute-force mitigation, invalid-session behavior after logout under adversarial concurrency.
- [ ] HTTPS/HSTS/secure cookies, trustworthy proxy settings, server-side secret provision and rotation, request logging privacy.
- [ ] Existing production `config/database.yml` is localhost/postgres oriented; design managed PostgreSQL, secret URLs, backups and rollback.
- [ ] Audit public consultations for personal data; privacy policy for demo.
- [ ] Staging boot, migration verification, browser and mobile smoke evidence; no public Railway deploy until explicitly agreed.
- [ ] Future dependency automation (e.g. Dependabot) after human signoff.

## References
- https://rubyonrails.org/maintenance
- https://rubyonrails.org/2026/11/4/Rails-8.0.5.2-and-8.1.4.1-have-been-released
- https://www.ruby-lang.org/en/downloads/branches/
- https://guides.rubyonrails.org/upgrading_ruby_on_rails.html
- https://github.com/advisories/GHSA-qpgp-93vx-g8v8
- https://github.com/advisories/GHSA-2vqw-3mp8-cgmx
- https://github.com/advisories/GHSA-67mh-4wv8-2f99
- https://github.com/advisories/GHSA-qppm-g56g-fpvp
