# RC-023 — read-only staging restore preflight (Draft)

**Date:** 2026-11-07. **Parent:** RC-022 / PR #23. **Purpose:** independently inspect the owner's privately held PostgreSQL custom archive and prove that the *proposed* disposable staging database name is absent from the explicitly selected PostgreSQL endpoint **without any database modification**.

## Boundaries and evidence levels

- This preflight makes **no** `CREATE DATABASE`, `DROP DATABASE`, `pg_restore --dbname`, `rails db:migrate`, application writes, merge or deployment.
- A `PREFLIGHT PASS` proves an expected SHA256 match, custom PGDMP header, PostgreSQL 18 `pg_restore` TOC/data parsing to `/dev/null`, read-only access to the selected server and absence of the target database name **at the time of query**.
- It **does not** prove that the selected host is isolated from live services, that a restorable full logical backup is complete, that a real restore succeeds, or that subsequent RC-022 migration/rollback works.
- An independent operator/owner must validate the staging host/account identity, network/TLS policy, storage and blast radius. This manual check cannot be inferred from a hostname or an environment variable.

## Read-only operator procedure

1. Keep the archive privately on the owner's computer with permissions `0600`. The recorded location is `$HOME/.local/share/rails_calendar/backups/ruby_calendar_pre_rc018_2026-11-07.dump`. The owner previously demonstrated a readable *PGDMP* archive created by `pg_dump 18.6` from a PostgreSQL 16.11 server; **no isolated restore has yet succeeded**. Record and retain its SHA256 separately in a private local file before testing. Do not put any archive, credentials, checksum provenance file or client data in GitHub/Notion/shared Drive.
2. Identify the **separate approved staging PostgreSQL server**, its nonproduction login and libpq authentication (e.g. a protected `.pgpass` or `PGPASSFILE`, never a password in this document/PR). It must permit a read-only query to the `postgres` maintenance database. A dummy example of environment variable names:

   ```bash
   export RC_RESTORE_ARCHIVE="$HOME/.local/share/rails_calendar/backups/ruby_calendar_pre_rc018_2026-11-07.dump"
   export RC_EXPECTED_SHA256='<previously-recorded-64-character-hash>'
   export RC_STAGING_DB='rc_restore_rc022_20261107'
   export RC_STAGING_PGHOST='<separately-verified-staging-host>'
   export RC_STAGING_PGPORT='5432'
   export RC_STAGING_PGUSER='<staging-readonly-username>'
   # Explicitly clear inherited application target, not credentials.
   unset DATABASE_URL
   bash bin/rc-staging-restore-preflight
   ```

   An absolute PostgreSQL 18 `pg_restore` executable is required at `/usr/lib/postgresql/18/bin/pg_restore` (or `RC_PG_RESTORE_BIN` for an explicitly verified alternative). Do not use `pg_restore 16` for this custom archive. The preflight uses `psql -X -w` and `default_transaction_read_only=on`, never prompts for a password, and refuses to run when `RAILS_ENV`/`RACK_ENV` is `production` or `DATABASE_URL` is present.
3. Expect `PREFLIGHT PASS` and `NO RESTORE EXECUTED`. Otherwise stop. Nonexistent or already-present target, invalid checksum, incompatible parser, missing permissions or unavailable endpoint cause failure. Protect `ruby_calendar`, `ruby_calendar_test` and all non-`rc_restore_...` names by design. **Do not manually bypass a failed preflight.**

## Offline test evidence

`bash test/scripts/rc_staging_restore_preflight_test.sh` uses disposable mocked executables and a tiny synthetic PGDMP-header file. It tests both the positive control and fail-closed scenarios: target exists, protected name, SHA mismatch, old `pg_restore`, inherited `DATABASE_URL`, production app environment. It never contacts PostgreSQL and does not qualify as staging acceptance. CI invokes `bash -n` and the hermetic tests before the Rails test suite.

## Release gates still blocked

- [ ] Owner verifies isolated staging server and approves **a later separate** state-changing restore drill.
- [ ] Restore to a newly created empty disposable DB with controlled privileges; compare table counts, preserved IDs, migration state and data checksums using non-PII reporting.
- [ ] Apply and roll back RC-022 migration on **separate copies**, with reproducible recovery; do not run against owner local or production records.
- [ ] Stage HTTP TLS termination, cookies/CSRF, login 429/503 under trusted proxy and access isolation.
- [ ] Do not merge the nested Draft PR stack or deploy until owner explicitly approves the combined release gate.

Source: [RC-021 SOP](RC021_P0_SECURITY_RECOVERY_GATE_2026-11-07.md), [RC-022 acceptance](RC022_RESCHEDULE_HISTORY_2026-11-07.md), [ADR-002](ADR002_RESCHEDULE_AUDIT_CAPACITY_2026-11-07.md). Status: **preflight guard implemented; real staging restore NOT attempted**.
