# R0.4 — Local review DB migration and backup gate (not executed)
Date: 2026-11-21. Status: **DOCUMENTED, NOT RUN, NOT APPROVED FOR WRITES**.

## Distinguish verified environments
- User's checkout `~/rails_calendar_ai_c21c`, local HEAD `c25be48`, `db/schema.rb` modified. Ruby 3.4.13 selected via `ASDF_RUBY_VERSION`, but running port 3002 may still be an earlier process.
- Exact user-supplied read-only psql identity: database **`rails_calendar_rc0551f_c21b_review_20261117`**, role **`gor`**, PostgreSQL **16.11**, Unix **socket**.
- This read-only connection used `RC_LOCAL_DEV_DATABASE_URL`. **We have NOT verified that Rails on port 3002 uses that same database**; confirm effective connection in a read-only reviewed process before doing any write.
- Historical scripts `script/rc0551f_c21_backup_preflight.sh`, `script/rc0551f_c21_backup_and_verify.sh` point at **`rails_calendar_mvp_preview_20261112`**, a different DB. `script/rc0551f_c21a_migrate_scratch_only.sh` points at an older named restored scratch database and specific migration. Never run them against the observed C2.1b review DB without rewriting and reviewing every target/check.
- Source branch contains new outbox migration `20261121003000_create_domain_outbox_events.rb`, currently only CI/test migrated. No local migration or any Railway production migration has been authorized.

## Phase A. Read-only inventory — allowed now
1. Print only short Git SHA, `git status --short`, `git diff --stat -- db/schema.rb`; do NOT paste private or unredacted DB configuration.
2. Verify `DATABASE_URL` is not unexpectedly set; never echo its value. `PGOPTIONS='-c default_transaction_read_only=on' psql "$RC_LOCAL_DEV_DATABASE_URL" -X -w -v ON_ERROR_STOP=1 -Atc "SELECT current_database(), current_user, current_setting('server_version'), COALESCE(inet_server_addr()::text,'socket');"`.
3. Require the exact expected DB name, role, local socket and major 16; fail closed if different, remote, missing var or interactive login. The earlier result already confirmed one connection; run once again immediately before backup.
4. Read-only count/list of existing tables (`schema_migrations`, `activity_events`, `active_storage_blobs`, `active_storage_attachments`, `intake_requirement_sets`, `domain_outbox_events` if present), and `SELECT version FROM schema_migrations ORDER BY version DESC LIMIT 10` with explicit quoting and sensitive-output restrictions.
5. Confirm `storage/` is real directory (not symlink), identify actual Active Storage service in `config/storage.yml`; never assume files under `storage/` cover all blobs.
6. Check existing DB client sessions/readers, stopped owner writers and worker processes. This needs a separate terminal screenshot/list, not guessing. `ss` port 3002 only proves a server is listening, not which DB it serves.

## Phase B. Explicitly approved, private backup and isolated restore (NOT YET DONE)
- Require user confirmation and proof target is **`rails_calendar_rc0551f_c21b_review_20261117`** (not any historical preview DB), no inherited production `DATABASE_URL`, no active writes, sufficient disk, user-private backup directory mode 0700 and created files mode 0600. Do not print tokens or store archives in GitHub/Notion/Drive/ChatGPT.
- Use pinned matching PostgreSQL **16** `pg_dump`, `pg_restore`, local socket; take a consistent custom archive from exact source DB and separate private media snapshot of actual Active Storage backend. Record checksums and archive TOC. If cloud Active Storage backend is configured, follow its supported secure snapshot mechanism; never silently skip it.
- Restore **only to a newly created and name-verified scratch database** that is separate from review DB and production. Verify schema migrations, table counts, FK integrity and media checksums; perform private synthetic read tests with no client/public exposure.
- Preserve scratch DB and private backup until explicitly authorized cleanup. A successful `pg_dump` without restore check is NOT R0.4 complete.

## Phase C. Rehearsal/migration, only after explicit authorization
1. Validate the exact Rails connection again (database, server, socket, user, environment), and ensure no pending unrelated migrations. Git code SHA and `schema_migrations` must correspond.
2. On the **restored scratch DB only**, try the **specific** migration `20261121003000` with an isolated environment that cannot reach production; prove new constraints/table, run targeted tests/read-only outbox simulation, compare counts. Do NOT connect Rails process port 3002 to the scratch without a distinct port and documented isolation.
3. Produce a safe rollback plan that does not destroy canonical production data. Once migration has processed new writes, simply rolling back a migration may cause data loss; require a restoration/business decision.
4. Only after proven backup+restore, scratch rehearsal, exact-head CI/Security, owner UI acceptance and explicit permission, migrate the **review DB**. Never `db:reset`, `db:prepare`, `db:schema:load`, or auto-revert `db/schema.rb`.

## Phase D. QA and deployment
- Restart isolated preview at :3002 with Ruby 3.4.13 from the exact local checkout; original :3001 untouched.
- Test month/day/hour event links and new C2.3b outbox with fictional rows, owner/client/foreign owner, 320/390/1440, no AI charges on replay.
- Production Railway remains a distinct staged release, with PostgreSQL 18 baseline migration verification, storage backup/restore, workspace permissions and explicit authorization.

**Current gate:** DB identity proof exists for one read-only psql connection; no verified backup+restore of this review DB, no confirmed effective Rails DB, no staged local migration. Status `R0.4 BLOCKED`.
