# RC-003 — Ruby/Rails modernization and dependency security

Date: 2026-11-06. **Audit baseline, not a completed upgrade.** Educational/demo app only.

## Verified input

- Source: [RC-002 Draft PR #2](https://github.com/TheGor-365/rails_calendar/pull/2), SHA `bdfbeca0e494d2b44e1cf17698a63ee6da7e4baf`.
- Existing `Gemfile` pins Ruby 3.1.2 and Rails ~> 7.0.4; `Gemfile.lock` resolves Rails 7.0.4.1, Puma 5.6.5, Selenium 4.7.1, webdrivers 5.2.0, Bundler 2.3.7.
- Existing JavaScript: Yarn classic lockfile; `esbuild ^0.17.3`, Bootstrap ^5.2.3, legacy Turbo JS ^7.2.4.
- [RC-002 CI success](https://github.com/TheGor-365/rails_calendar/actions/runs/42123257376): 24 unit/integration tests (64 assertions) + 6 browser tests (18 assertions), 0 failures/errors.
- Security scanning is now deliberately separate from functional CI. Audit failures must be treated as confirmed remediation blockers, not disabled/ignored to create a green release badge.

## Target runtime and evidence

- Ruby **3.4.12**, published 2026-10-23; supported maintenance branch. https://www.ruby-lang.org/en/downloads/releases/
- Rails **8.1.4.1**, published 2026-11-04; security-supported Rails branch. https://rubyonrails.org/2026/11/4/Rails-8.0.5.2-and-8.1.4.1-have-been-released
- Rails 7.2 is *not* an acceptable final destination in November 2026; use the release guide's staged migration process to detect compatibility issues. https://guides.rubyonrails.org/upgrading_ruby_on_rails.html

## Migration work packages (pending)

1. **RC-003A**: analyze current Ruby/Gemfile/Gemfile.lock and JS lockfile findings; record each advisory, severity, fixed version and affected code path. This branch adds *read-only* CI audit jobs; they are expected to fail when vulnerable dependencies are found.
2. **RC-003B**: trial upgrade Ruby to 3.4.12 with regenerated Gemfile.lock using Bundler on the actual target runtime. Never hand-edit the lockfile's resolved dependency versions. Keep CI on isolated PostgreSQL.
3. **RC-003C**: staged Rails migration (7.0 final patch → 7.1 → 7.2 → 8.0 → 8.1.4.1) with `bin/rails app:update` review at each stage. Keep local application-specific configurations and explicit auth policies. Run model, controller and browser tests for each checkpoint.
4. **RC-003D**: update/remove obsolete gems (`webdrivers`, Selenium, Puma, bundlers, asset packages) only after compatibility testing; rebuild Yarn lock under a pinned compatible toolchain and run advisory scan again.
5. **RC-003E**: production security gates: HTTPS/secure cookies, admin login rate limit, confidential data audit, credential store, safe DATABASE_URL, backup/rollback, staging smoke + user approval. No production deployment until done.

## Status and safety invariants

- This branch and its PR are **Draft**; it contains baseline audit automation/documentation, not an upgraded Ruby/Rails application.
- `main`, prior Draft PR #1/#2 and Railway must not be modified.
- Do not set external admin secrets or copy private user/consultation data to public logs.
- Do not treat green functional CI as zero vulnerabilities. Review the Ruby and Yarn audit logs to update this document with evidence.
