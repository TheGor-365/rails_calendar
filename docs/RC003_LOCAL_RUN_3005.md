# Rails Calendar — isolated local launch (Linux Mint)

Verified target branch: `upgrade/rc-003-ruby-3-4-rails-8-1-2026-11-06` (Draft PR #3).
Ruby: 3.4.12; Rails: 8.1.4.1; package manager: Yarn classic.

## One app, one directory, one port, one database

Run these commands from a **new dedicated clone**. Do not `bundle install`, `db:prepare`, or change Ruby versions in your other apps' directories.

```bash
git clone https://github.com/TheGor-365/rails_calendar.git rails_calendar
cd rails_calendar
git fetch origin
git switch --track origin/upgrade/rc-003-ruby-3-4-rails-8-1-2026-11-06
asdf install ruby 3.4.12   # skip if already installed
asdf local ruby 3.4.12     # local to this clone, not the other apps
ruby -v
gem install bundler -v 2.6.9 --no-document
bundle _2.6.9_ config set --local path vendor/bundle
bundle _2.6.9_ install
npx --yes yarn@1.22.22 install --frozen-lockfile
npx --yes yarn@1.22.22 build
npx --yes yarn@1.22.22 build:css
bin/rails db:prepare      # development DB ONLY: ruby_calendar
bin/rails server -b 127.0.0.1 -p 3005
```

Open http://127.0.0.1:3005 (admin form: http://127.0.0.1:3005/admin/login). The other Rails services may remain on ports 3000/3001/etc.

### Admin login for local testing
Set unique `RAILS_CALENDAR_ADMIN_USERNAME` and `RAILS_CALENDAR_ADMIN_PASSWORD` as environment variables **locally** before starting the server. Do not commit passwords, put them into shell history or share them in chats. No environment secrets means no admin login (fail closed).

### Independent databases
- Development: `ruby_calendar`
- Test: `ruby_calendar_test`
- Production: only an explicitly provisioned `DATABASE_URL` (no fallback to local Postgres).

```bash
# In another shell, from THIS project's directory:
RAILS_ENV=test bin/rails db:prepare
RAILS_ENV=test bin/rails test
RAILS_ENV=test bin/rails test:system
```

`bin/rails db:prepare` is destructive **if pointed at a different environment**; check `RAILS_ENV`, `DATABASE_URL`, and `PGHOST` before running. Do not run it against production.

## Optional bin/dev with live asset watches
For `bin/dev` install Yarn Classic in a **dedicated user toolchain**, or put a project-local Yarn executable on `PATH`. The `Procfile.dev` web process binds **127.0.0.1:3005** by default. `bin/rails server -p 3005` above works without foreman/watchers once JS and CSS have been built.

## Troubleshooting
- Port in use: `ss -ltnp | grep ':3005 '` (choose another unused port; do not kill other projects).
- Verify Ruby: `ruby -v` must print 3.4.12; check `asdf current ruby`.
- Verify committed lockfiles: `bundle _2.6.9_ check` and `npx --yes yarn@1.22.22 install --frozen-lockfile`.
- Never launch the demo publicly until human code review, hardening, secrets/PII audit, backup and isolated staging smoke checks.
