# C2.3b7k — invitation index catalog mismatch: offline root-cause triage

**2026-11-23 · Draft PR #81 · one approved local PG16 catalog observation FAILED CLOSED; NO REMEDIATION / NO SECOND PG16 QUERY.**

## Owner-terminal evidence: C2.3b7j single authorized read

The owner ran the previously reviewed local operator *once* from detached, previously verified clean `/home/gor/rails_calendar_c23b7j_catalog_worktree_20261123`, exact code SHA `6ae550d5bd0c98201b77356526325af4c5d3182e`, direct `/home/gor/.asdf/installs/ruby/3.4.13/bin/ruby`. The terminal printed:

```text
Syntax OK
RUBY_AND_GIT_PREFLIGHT=PASS
STARTING_ONE_READ_ONLY_METADATA_QUERY
C2.3B7J_SCRATCH_CATALOG=BLOCKED
REVIEW: missing index client_request_invitations.index_client_request_invitations_on_workspace_id_and_created_at unique=false
RESTORE_MEDIA_TENANT_SOURCE_AND_SCAN_AUTHORIZATION=NOT_VERIFIED
NO_DATABASE_WRITES_OR_SOURCE_ROWS_READ=TRUE
```

Interpretation: the operator's **read-only PostgreSQL catalog SQL completed and returned a parsed report**, but the minimum six-family contract **blocked**. The *only reported contract violation* was a missing **valid+ready, non-unique** named index on `public.client_request_invitations`. That does not prove the index is literally absent: the metadata probe filters indexes with `pg_index.indisvalid = false` or `indisready = false`, and expects exact name plus `indisunique = false`. A different name, wrong uniqueness, invalid/unready state or a genuinely absent index would all appear as the same contract mismatch. No raw PostgreSQL catalog was exported to chat or repo. Because the command is single-shot and fail-closed, **do not rerun it**.

In this report the required table/column/migration/FK/other index/CHECK *name-level* contract generated no additional messages; this does **not** validate column types/not-null, FK definition and existing row-level lineage, index key order/predicates, backup/media consistency, role ACL or tenancy. **G5 status = BLOCKED**, not PASS or corrupt-DB diagnosis. The user-terminal evidence reports no DDL/DML, provider, Rails boot, migration, restore, backfill/replay or production activity. The prior R0.4b2 restore and R0.4c4 one-off outbox migration were not repeated.

## Offline source triangulation (no DB access)

Checked at current Draft PR #81 lineage:
- `db/migrate/20261119000500_create_client_request_invitations.rb` explicitly adds `add_index :client_request_invitations, [:workspace_id, :created_at]` without `unique: true`; Rails' generated name is `index_client_request_invitations_on_workspace_id_and_created_at`.
- Tracked `db/schema.rb` includes exactly `t.index ["workspace_id", "created_at"], name: "index_client_request_invitations_on_workspace_id_and_created_at"` (non-unique).
- The subsequent existing migrations `20261119200000`, `20261119223500`, `20261120120000`, `20261120183000`, `20261120204500`, `20261121003000`, `20261121120000`, `20261121140000` and `20261122130000` do **not** remove/rename/redefine this invitation index. The later `20261120204500` change is to the **different** `intake_requirement_sets` source index, not the invitation index.
- `lib/domain_outbox/six_family_scratch_schema_contract.rb` requires that exact invitation index with `unique=false`. `lib/domain_outbox/six_family_scratch_metadata_probe.rb` exposes only `indisvalid && indisready` index names and uniqueness flags. The static index expectation is consistent with the committed migration and schema. Existing isolated CI ephemeral schema has passed this contract. **This does not establish why the owner's historical PG16 scratch differs.**

Do NOT: remove the contract invariant, weaken the check, silently create/reindex/drop/rename an index, mark a migration applied, force a new restore, touch source DB, inspect client invitations or run an unapproved second catalog query.

## Proposed next independent narrow gate — separate owner permission required

If the owner *separately authorizes one new metadata-only inspection*, design and independently review a fixed, pinned, guarded PostgreSQL 16 catalog query restricted to **only**:
- identity: `current_database()`, `current_user`, `server_version_num`, Unix socket and read-only transaction marker;
- the `pg_class`, `pg_namespace`, `pg_index`, `pg_attribute` metadata for `public.client_request_invitations` and its indexes: existence, **all actual index names and parent relation**, valid/ready flags, uniqueness, key order and optional predicate/expression *definitions*, without any table rows;
- the exact historical scratch target `rails_calendar_r04_restore_20261121t231331z_27407`, local PG16 socket, owner role `gor`, `default_transaction_read_only=on`, a noninteractive client, a timeout and sanitized output with no credentials, private paths or raw IDs.

Classify observed metadata as `EXACT_EXPECTED_INDEX_PRESENT`, `INDEX_ABSENT`, `INDEX_INVALID_OR_NOT_READY`, `INDEX_NAME_OR_DEFINITION_DRIFT`, `INDEX_UNEXPECTEDLY_UNIQUE` or `UNKNOWN`. Any failure still = `G5 BLOCKED`. An observation is NOT authorization to repair the index. Later, a repair requires a **separate** owner-approved plan including a current private backup and review of what was restored and what migrations were actually applied.

**Current next step:** an **offline** review of this source-backed gate and an explicit opt-in for one new catalog-only lookup. No further local PG16 connection has been authorized by the completed one-shot C2.3b7j check. Other recovery/tenancy/media/backup gates G3/G4/G6, manual C2.2 QA and release remain OPEN.
