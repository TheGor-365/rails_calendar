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

## R0.4a checkpoint: verified Rails DB + actual root storage (21 November 2026)
- **User-verified using the standalone Rails process**, without DB writes: `rails_calendar_rc0551f_c21b_review_20261117|gor|160011|socket|false`. PostgreSQL 16.11, `domain_outbox_events` absent. The live server at :3002 has **not** been separately verified.
- **User-verified actual development Active Storage service:** `local`; `storage/` is a real directory (not a top-level symlink), owner `gor`, mode **775**. **Group is writable**; group name/members, *nested* symlinks, unusual files and current disk space are still unverified. Changing permissions now is NOT authorized. This is a security review finding, not proof of a breach.
- **New read-only preflight in the Draft PR:** `script/rc0551f_r04_review_db_preflight.sh` hardcodes this exact **review** DB, local PG16 socket and user, checks PSQL read-only identity, structural row counts, active connections, `storage/` ownership/mode, nested symlinks, file counts, bytes and HOME free space. No archive, new database, migrations, permissions changes, or user data content are produced. The offline deny tests are `test/scripts/rc0551f_r04_review_db_preflight_test.sh` and are wired into Rails CI.
- The preflight is **NOT YET RUN on user's Linux machine**, and its new code SHA is **NOT CI-VERIFIED until exact-SHA Actions pass**. Its existence in remote PR #81 is not proof that user's older local checkout contains the script.
- The older C2.1 backup scripts targeting `rails_calendar_mvp_preview_20261112` remain **UNSAFE for this source DB**. Do not copy/rename them blindly or run them. A distinct reviewed exact-db backup+scratch-restore writer is still NOT IMPLEMENTED for R0.4 and requires explicit user approval.
- Before private media archive, check actual `storage/` group membership and nested symlinks, Active Storage blob root and actual :3002 writers/readers. A local backup requires mode 0700 directory, 0600 archives; never upload private archives or data to Github/Drive/chat.

## Phase B. Explicitly approved, private backup and isolated restore (NOT YET DONE)
- Require user confirmation and proof target is **`rails_calendar_rc0551f_c21b_review_20261117`** (not any historical preview DB), no inherited production `DATABASE_URL`, no active writes, sufficient disk, user-private backup directory mode 0700 and created files mode 0600. Do not print tokens or store archives in GitHub/Notion/Drive/ChatGPT.
- Use pinned matching PostgreSQL **16** `pg_dump`, `pg_restore`, local socket; take a consistent custom archive from exact source DB and separate private media snapshot of actual Active Storage backend. Record checksums and archive TOC. If cloud Active Storage backend is configured, follow its supported secure snapshot mechanism; never silently skip it.
- Restore **only to a newly created and name-verified scratch database** that is separate from review DB and production. Verify schema migrations, table counts, FK integrity and media checksums; perform private synthetic read tests with no client/public exposure.
- Preserve scratch DB and private backup until explicitly authorized cleanup. A successful `pg_dump` without restore check is NOT R0.4 complete.

## R0.4b prepared (NOT RUN) — exact private DB/media archive with scratch restore

**User read-only storage output 2026-11-21:** `storage/` owner `gor`, group `gor`, mode **775**, **0 nested symlinks**, **12 regular files**, approximately **16 MiB**. `getent group gor` returned `gor:x:1000:` (no listed supplementary members); this is **not** a proof that another account does not have primary GID 1000. The root filesystem `/dev/sda11` is **92% used**, **23 GiB available** from `df -h`. Do not change permissions or delete files as an unapproved shortcut. The actual DB size has not yet been measured.

- **Prepared in Draft PR, not in owner's older local checkout:** `script/rc0551f_r04_review_db_backup_restore.sh` at code SHA `8720bd519c2696fd858c71e13bbd901c7f01f08a` and `test/scripts/rc0551f_r04_review_db_backup_restore_test.sh`; offline negative tests wired to `.github/workflows/ci.yml`. This is a backup/restore **writer**, strictly separate from the read-only R0.4a preflight. It has **not been executed locally** and it is **not CI-verified until that exact SHA passes**.
- Stop conditions before any writer action: `RAILS_ENV=development`, `DATABASE_URL` absent, explicit RC local URL, OS role gor, pinned exact checkout path, explicit `RC_CONFIRM_SOURCE_DB`, `RC_CONFIRM_WRITERS_STOPPED=YES`, `RC_CONFIRM_PRIVATE_BACKUP_AND_RESTORE=YES`, `RC_CONFIRM_STORAGE_GROUP_REVIEW=YES`. No production environment, other source DB or old preview DB accepted.
- Effective disk backend checked using a separate Rails runner and `File.realpath(ActiveStorage::Blob.service.root)`. Reject storage symlinks/special files, non-gor ownership/group, supplementary or other primary members of the writable storage group, port **3002** still listening, or any other session on the exact review DB. Port **3001** is protected and never stopped by this script.
- Fixed PostgreSQL 16 clients and Unix socket, exact source name/role; an independent read-only check of `RC_LOCAL_DEV_DATABASE_URL` must resolve to the same DB/role/socket/version. Refuse unknown Active Storage blob service names, missing core tables, or an already-existing outbox table (schema drift).
- Fixed user-private directory `~/.local/share/rails-calendar/review-backups-r04`, no symlink/group-writable ancestors, mode 0700 session directory and owner-only archive files via `umask 077`. Conservative disk-space gate: **4 × actual DB bytes + 3 × storage bytes + 2 GiB reserve** before archive. With 23 GiB free this may be a blocker if DB is large; never infer DB size from number of storage files.
- PostgreSQL `pg_dump -Fc` + `pg_restore -l`, local `tar` media snapshot, SHA-256, archive extraction + private byte comparison; `createdb` uses a newly named scratch DB, `pg_restore --exit-on-error` does **not** pass `--clean`. Compare public table counts, key row counts and exact `schema_migrations` versions. Preserve both backup and scratch DB; no `dropdb`, `db:reset` or automatic cleanup. No production traffic or AI calls.
- **Evidence not yet available:** disk database size, actual ActiveStorage disk root path, other primary members of gid 1000, source writer shutdown, isolated restore checksum/count report, and manual browser QA. The mere existence of the script does **not** close R0.4b. Never paste private archive contents into this chat.
- **Mandatory sequence:** verify exact-SHA CI and review script, perform read-only group/DB size/root checks, ask for explicit user approval of the backup+scratch action, then the user runs a reviewed command in their local environment. The assistant must not claim a backup exists from a code commit.

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
