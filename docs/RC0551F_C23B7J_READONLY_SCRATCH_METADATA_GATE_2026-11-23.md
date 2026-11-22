# C2.3b7j — exact PG16 scratch **metadata-only** operator probe

**2026-11-23 · Draft PR #81 · preparation and CI ONLY.** This gate turns [C2.3b7i's 17-table/10-migration register](RC0551F_C23B7I_SCRATCH_SCHEMA_REGISTER_2026-11-23.md) into a controlled **catalog-only** observation tool. It does **not** execute the tool on the owner's computer, open the private archive, touch the original review database, migrate the old scratch, replay/backfill, inspect client records, call a provider or deploy. The user still decides whether/when to invoke an explicitly pinned read-only command on a separately reviewed local worktree.

## Source of truth and known baseline

- Existing [PR #81](https://github.com/TheGor-365/rails_calendar/pull/81) at pre-slice head \`4bcc979d0417564e890c5e06cf0b09f9ffdac1be\`: Rails CI #45071698432 SUCCESS; Security Audit #45071698532 SUCCESS. Functional C2.3b7i SHA \`9db6f0e0\`: Rails CI #45071359034 SUCCESS; Security Audit #45071359111 SUCCESS.
- Historically the owner, on 22 November, independently validated an existing private PG16 scratch restore (\`R0.4b2\`) and exactly one approved scratch-only outbox migration (\`R0.4c4\`, \`20261121003000\`). **Do not repeat either operation.** Exact scratch identity recorded in old private operator evidence: \`rails_calendar_r04_restore_20261121t231331z_27407\`; source review database: \`rails_calendar_rc0551f_c21b_review_20261117\`. These names are for guarded target selection only; no query to source review DB is permitted.
- Four scanner-essential tables (\`intake_scope_revisions\`, \`intake_requirement_sets\`, \`domain_outbox_events\`, \`activity_events\`) are absent in the **tracked GitHub \`db/schema.rb\`** at old HEAD; migration files exist. **Actual target PG16 catalog remains UNKNOWN.** A schema migration previously verified on scratch says nothing about presence of the other three tables or their constraints.
- Scope revisions and requirements require migration versions \`20261120120000\`, \`20261120183000\` and \`20261120204500\`. The last makes \`idx_intake_requirement_sets_source\` **NON-UNIQUE** while keeping \`idx_intake_requirement_sets_version\` unique (see earlier CI correction). This is a legitimate model contract, not a repair instruction.

## What has been added

1. \`lib/domain_outbox/six_family_scratch_metadata_probe.rb\`: fixed SQL text; reads only \`pg_catalog.pg_class\`, \`pg_namespace\`, \`pg_attribute\`, \`pg_constraint\`, \`pg_index\`, \`pg_stat_activity\`, \`schema_migrations.version\` on the **selected connection**. It returns connection identity, one other-session count and catalog metadata for the exact 17 allowlisted tables. It NEVER performs \`SELECT\` on those tables, even for \`count(*)\`, and never reads their row contents, PII, archive files, media, credentials, AI transcripts, invitation secrets or financial ledger.
2. \`script/rc0551f_c23b7j_scratch_catalog_readonly.rb\`: a **manual/local** operator wrapper. It rejects unknown arguments, missing one-off approval token, wrong explicitly reviewed scratch name, production/test RAILS_ENV, inherited DB/PG connection variables, incorrect OS user, changed/dirty checkout, wrong pinned PG16 executable, missing local socket, non-local/incorrect connected identity, other sessions and non-read-only mode. Its only database action is one \`psql -X -w -q -A -t\` read-only SELECT with \`PGOPTIONS=default_transaction_read_only=on\`, statement/lock timeouts and an explicit Unix socket, role and exact scratch database. Psql stderr/JSON are captured, not printed; public output is bounded PASS/BLOCKED + structural object names only. \`RC_EXPECTED_HEAD_SHA\` must match the checked-out 40-character Git HEAD; never set it to a value based on an unverified local checkout.
3. \`test/lib/domain_outbox/six_family_scratch_metadata_probe_test.rb\`: CI-only: introspects GitHub Actions' disposable PG15 test catalog, compares against the existing contract, uses synthetic identity for positive assessment, checks wrong target/role/version/socket/read-only/other-sessions and missing objects, and launches the **wrapper only on paths that must be denied before connection**. No CI test connects to local PG16, private backup or Railway.

### Why a schema-only PASS is not a safety release

The wrapper calls \`SixFamilyScratchSchemaContract.violations\`, which validates name-level presence of 17 tables, required source columns, 10 migration versions, matching single-column FK targets, named indexes with unique flags and validated/ready named CHECK/index/FK catalog entries. The PostgreSQL query deliberately excludes **invalid/unready** indexes and **unvalidated** FKs/CHECKs, causing a fail-closed missing-object result. It does **not** prove column data types and nullability, index key column order/predicate, full row-level FK lineage, tenant isolation, archive fidelity, restored media bytes, backup chronology, absence of writes outside the observation instant or independent source/target cohort consistency. These remain separate G3–G6 operator evidence.

Even \`C2.3B7J_SCRATCH_CATALOG=PASS\` means **catalog-only structural evidence on a named socket** — never approval for the six-family historical scan, a writer, \`db:migrate\`, Rails startup, production or data publication. For \`BLOCKED\` or an unexpected exception: preserve the original scratch and backup; inspect *only* the missing metadata with a separate approved plan, do not attempt auto-repair.

## Separate owner-run gate (NOT performed by ChatGPT)

**No local command is issued by this documentation or GitHub Actions.** Only after an owner has reviewed the pinned final commit, its exact-SHA Rails/Security workflows, a **clean separate checkout** (never reset/overwrite the original \`~/rails_calendar_ai_c21c\` with modified \`db/schema.rb\`) and confirms the same old scratch PG16 Unix socket endpoint, the future *read-only* audit may be manually invoked.

Required private conditions: authenticated local user \`gor\`, executable \`/usr/lib/postgresql/16/bin/psql\`, active \`/var/run/postgresql/.s.PGSQL.5432\`, no inherited \`DATABASE_URL\`, \`RC_LOCAL_DEV_DATABASE_URL\`, \`PGHOST/PGHOSTADDR/PGUSER/PGDATABASE/PGPORT/PGSERVICE/PGSERVICEFILE/PGPASSWORD/PGOPTIONS\`; development-only app environment; exact checkout SHA and scratch name. Never print DB connection URIs, secrets, private archive file paths, raw JSON catalog or source row IDs.

**Illustrative environment for a *future* explicitly authorized, clean pinned worktree (not a command to run today):**

\`\`\`bash
# Inside a separate clean worktree whose HEAD has already been pinned.
# No checkout, migration, restore, backup, rake, source read or Railway command.
env -u DATABASE_URL -u RC_LOCAL_DEV_DATABASE_URL \
    -u PGHOST -u PGHOSTADDR -u PGPORT -u PGUSER -u PGDATABASE \
    -u PGSERVICE -u PGSERVICEFILE -u PGPASSWORD -u PGOPTIONS \
    RAILS_ENV=development \
    RC_EXPECTED_HEAD_SHA='<exact-reviewed-final-40-hex-commit>' \
    RC_REVIEWED_SCRATCH_NAME='rails_calendar_r04_restore_20261121t231331z_27407' \
    RC_APPROVE_C23B7J_METADATA_READ='YES_METADATA_ONLY' \
    ruby script/rc0551f_c23b7j_scratch_catalog_readonly.rb
\`\`\`

**Do not treat the illustrative command as an instruction to immediately run it** without verifying the local worktree, correct role/socket/DB identity, backup protection and independent owner permission. It explicitly refuses the original dirty checkout. There is no interactive password prompt; missing peer/libpq authorization fails closed.

## Accepted outputs and interpretation

| Sanitized line | Meaning |
|---|---|
| \`STOP C2.3b7j: ...\` | preflight failed, no catalog SQL (when pre-query) or safe query rejected. Never print raw errors or retry against another DB |
| \`C2.3B7J_SCRATCH_CATALOG=BLOCKED\` | one metadata query returned but at least one identity/schema/version/index/FK/CHECK gate is not met; structure-only review needed |
| \`REVIEW: missing ...\` | public schema object name only. A missing family object does **not** authorize any migration |
| \`C2.3B7J_SCRATCH_CATALOG=PASS\` | only 17-table/10-version metadata checks and the selected identity/session guard passed; recovery, source integrity and privacy remain unverified |
| \`RESTORE_MEDIA_TENANT_SOURCE_AND_SCAN_AUTHORIZATION=NOT_VERIFIED\` | always present after a parsed response |
| \`NO_DATABASE_WRITES_OR_SOURCE_ROWS_READ=TRUE\` | static bounded-SQL scope of this tool; not proof of global database quiescence |

**Evidence labels**: \`CODE_COMMITTED\` on the new feature commit; \`CI_VERIFIED\` only after exact-SHA Rails CI + Security success; \`LOCAL_CATALOG_PENDING\` until owner-supplied sanitized stdout from the pinned script; \`G3/G4/G6/PUBLIC_RELEASE_PENDING\` regardless of catalog result.

## Future gates after independent catalog evidence

1. Independently validate column data types/NOT NULL, FK/CHECK definitions, index key order and predicates, and media/SQL restored-vs-source parity without exposing real records; only if separately approved.
2. Verify private data governance, access scopes and stable source cohort before authorizing any bounded six-family **read-only** scan.
3. Corrective backfill writer, owner production migrations, Railway deploy and main merge stay **prohibited without new separate approvals**. Existing C2.2 manual owner/client/browser QA still OPEN.

**No owner-local DB access was performed in this code slice.** Do not claim that the old PG16 scratch is compatible based only on synthetic CI.
