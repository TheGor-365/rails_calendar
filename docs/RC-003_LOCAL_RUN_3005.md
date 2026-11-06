# Rails Calendar — isolated local development

## Isolation from other Rails projects
- Run this project in its **own clone and shell**; do not edit shared shell startup files or global Ruby versions.
- Web server listens on `127.0.0.1:3005` by default. Other projects may continue on `3000`, `3001`, etc.
- Database names are `ruby_calendar` (development) and `ruby_calendar_test` (test). Do **not** point `DATABASE_URL` at another app or a production database.
- Ruby `3.4.12`, Rails `8.1.4.1` are pinned in `.ruby-version` and `Gemfile.lock` after migration. Use `asdf` or `rbenv` per-project; no system-wide `gem install rails` needed.

## Linux Mint example (asdf already installed)
```bash
git clone https://github.com/TheGor-365/rails_calendar.git rails_calendar
cd rails_calendar
git fetch origin
git switch --track origin/feature/rc-003-runtime-security-audit-2026-11-06
asdf install ruby 3.4.12   # only if not installed; this may take time
asdf local ruby 3.4.12     # creates a project-local .tool-versions
ruby -v
gem install bundler        # if not present for THIS Ruby runtime
bundle config set --local path vendor/bundle  # local to this clone
bundle install
npm install --global yarn@1.22.22  # skip if already installed
yarn install --frozen-lockfile
bin/rails db:prepare       # ONLY ruby_calendar development DB
RAILS_CALENDAR_PORT=3005 bin/dev
```

If using `rbenv`, select Ruby 3.4.12 in the clone instead of running `asdf` commands. If `asdf` reads `.ruby-version` already, a local `.tool-versions` file is optional.

Open `http://127.0.0.1:3005`. To stop only this app, press Ctrl+C in its own terminal. To inspect port occupancy first: `ss -ltnp | grep ':3005 '`.

## Test (separate test DB, never production)
```bash
RAILS_ENV=test bin/rails db:prepare
RAILS_ENV=test bin/rails test
RAILS_ENV=test bin/rails test:system
```

## Local admin access
Set `RAILS_CALENDAR_ADMIN_USERNAME` and `RAILS_CALENDAR_ADMIN_PASSWORD` **only in your current terminal's environment** (never commit a .env or credentials). Then visit `/admin/login`. Missing credentials intentionally disable login. Do not use genuine client/patient records in a public demo.

## Release gate
Draft PR #4 is not production-ready until dependency audit, functional/system CI, admin security, and explicit staging smoke checks pass.
