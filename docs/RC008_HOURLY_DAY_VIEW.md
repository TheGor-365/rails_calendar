# RC-008 — Hourly day view and manual consultation scheduling

Date: 2026-11-06
Status: Draft PR, test/QA gated.
Parent: RC-007 Draft PR #7. Do not merge into main or deploy to production.

## User QA that triggered this change

At `127.0.0.1:3005`, the newly themed calendar month and consultations list rendered. Admin login rejected a password, leaving manual editing controls hidden. The product had no daily 24-hour detailed view.

## Implemented

- Public `/calendar/day?date=YYYY-MM-DD` displays 24 rows, 00:00–23:00 (Rails application timezone, currently UTC).
- Every month date number links to its daily schedule. The top navigation also exposes a Day view, plus previous/next day and Today.
- Day slots show consultations overlapping each hour, including sessions crossing midnight; long sessions appear in each overlapping hour marked Continues.
- When administrator is signed in, every hour provides an Add-at-time link opening a new consultation form with prefilled 60-minute period. Actual persistence remains admin-only in ConsultationsController.
- Day page is read-only for anonymous users. Out-of-range or malformed day parameters redirect safely.
- Minimalist visual rules from RC-007 retained. No dynamic calendar drag/drop, API, AI or native clients in this scope.

## Account recovery — local only

There is no administrator database record. Credentials are read from server environment variables `RAILS_CALENDAR_ADMIN_USERNAME` and `RAILS_CALENDAR_ADMIN_PASSWORD`. Their rotation immediately invalidates previous sessions.

Do not use the `test/test_helper.rb` demonstration credentials as real credentials. Never commit passwords. On local zsh terminal, stop Rails and run:

```zsh
cd ~/rails_calendar_3005
read -r 'RAILS_CALENDAR_ADMIN_USERNAME?New admin username: '
read -rs 'RAILS_CALENDAR_ADMIN_PASSWORD?New admin password: '
echo
export RAILS_CALENDAR_ADMIN_USERNAME RAILS_CALENDAR_ADMIN_PASSWORD
unset DATABASE_URL RAILS_ENV
bin/rails server -b 127.0.0.1 -p 3005
```

Then sign in at `/admin/login` with those new values. No password recovery endpoint exists. A secure account-recovery mechanism belongs to a later authenticated multi-user architecture milestone.

## QA gates

1. CI model/controller/system tests and security audit green on final head.
2. Manual local check: month → day, 24 hours, date navigation, mobile 360px, no horizontal body overflow.
3. Confirm login after local credential rotation; calendar and list display New consultation; 09:00 slot pre-fills 09:00–10:00.
4. Create, edit and delete one local test consultation; verify it appears on daily grid, and public signed-out user cannot mutate it.
5. Document chosen time zone before inviting external users (currently UTC, not a local-office setting).

Remain in Draft until human review and QA.
