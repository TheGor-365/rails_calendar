# C2.3b7m — Rails-generated invitation index name: offline contract correction

Date: 2026-11-23; existing Draft PR #81. This is an **offline code/test adjustment** only.

## Owner-reported bounded PG16 catalog evidence (C2.3b7l)

The owner executed the explicitly approved C2.3b7l read once from the independently verified clean detached worktree pinned to `b381bf419a3e969d59fbcad6593e0190bb0ac858`. The bounded stdout was:

```text
Syntax OK
C23B7L_PREFLIGHT=PASS
STARTING_ONE_AUTHORIZED_METADATA_QUERY
C2.3B7L_INDEX_VARIANT=ALTERNATE_NAME_VALID_READY
C2.3B7L_INDEX_NAME=idx_on_workspace_id_created_at_2c68e09548
C2.3B7L_DIFFERENCES=NAME
G5=BLOCKED
DATABASE_WRITES_AND_APPLICATION_ROW_READS=NOT_PERFORMED_BY_THIS_TOOL
BACKUP_MEDIA_TENANCY_AND_REMEDIATION=NOT_AUTHORIZED
OPERATOR_EXIT_CODE=2
NO_AUTOMATIC_RETRY=TRUE
```

**C2.3b7l permission is CONSUMED.** Do not repeat b7l or any preceding b7j/b7k operator. Owner output proves only that the bounded classifier found one nonunique valid+ready B-tree index on the ordered pair (`workspace_id`, `created_at`) with no included columns, predicate or expression, under another name. This proves no missing physical index in this scoped observation; not global 17-table parity, media integrity, restore authorization, tenant isolation, or runtime compatibility.

## Root cause, offline source corroboration

- Tracked migration `db/migrate/20261119000500_create_client_request_invitations.rb` uses `add_index :client_request_invitations, [:workspace_id, :created_at]` without an explicit index name.
- The long conventional name `index_client_request_invitations_on_workspace_id_and_created_at` is 63 bytes. ActiveRecord Rails 8.1 `max_index_name_size` is **62 bytes**, so its `generate_index_name` fallback hashes the long conventional name with SHA-256, retains the first 10 hex chars, and prefixes `idx_on_workspace_id_created_at_`.
- Deterministic hash confirms `idx_on_workspace_id_created_at_2c68e09548`, exactly the observed catalog name.
- Tracked `db/schema.rb` still declares the 63-byte conventional name; it is a **separate source/schema naming drift** requiring review before any checked-in schema update. The owner's local `db/schema.rb` is modified; do NOT reset, overwrite, checkout, or stash it.
- The old `SixFamilyScratchSchemaContract::INDEXES` required only the 63-byte name, which produced C2.3b7j's sole missing-index report even when the physical Rails index was usable.

## Minimal code-only remedy

Switch the static expected index name to the exact Rails-generated name and retain a **single allowlisted legacy alias** for databases created from the previously tracked `schema.rb`. Keep the existing `valid+ready` filtering and uniqueness checks, no wildcard matching. Add synthetic CI regression tests for the Rails SHA-256 index-name derivation, both accepted names, wrong name, and unexpected uniqueness. Neither schema.rb, migrations nor data are modified by this stage.

**Release gates:** The C2.3b7m code cannot be called CI_VERIFIED until the new exact-SHA Rails CI and Security Audit finish SUCCESS. Even if CI passes, **G5 remains BLOCKED** until a newly authorized independent scratch *full 17-table* catalog verification using code that includes this correction and new safety checks. Backup/media/tenancy/source integrity, owner local browser acceptance and production release stay OPEN. No index rename/drop/recreate, migration, source row scan, replay, Railway deploy, PR merge or real client data is authorized.