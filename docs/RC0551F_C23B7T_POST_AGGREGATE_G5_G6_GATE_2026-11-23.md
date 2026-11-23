# C2.3b7t — after two-database Active Storage aggregate parity: G5/G6 priorities

**Date 2026-11-23 | Draft PR #81 | OFFLINE NEXT-GATE DESIGN; no new owner consent or DB access.**

## Verified checkpoint C2.3b7s (owner terminal)

User ran exactly ONE separately consented and pinned C2.3b7s aggregate operator at functional code SHA `a35bf496f2446f6f52b6c543a25c935f322761b1`. Local Git preflight clean worktree was created at `~/rails_calendar_c23b7s_aggregate_worktree_20261123`. Ruby syntax of 3 files PASS. The operator returned:

```text
C23B7S_PREFLIGHT=PASS
PINNED_CODE_HEAD=a35bf496f2446f6f52b6c543a25c935f322761b1
WORKTREE_CLEAN=PASS
STARTING_ONE_AUTHORIZED_MAX_SIX_SELECT_READ
C2.3B7S_DB_AGGREGATES=AGGREGATE_PARITY
G4_ORPHAN_BLOB_REFS=ZERO
G4_MEDIA_KEY_FILE_REFERENCES=NOT_PROVED
G6_DB_OTHER_SESSIONS=ZERO_OBSERVED_AT_CHECKS
G6_WRITER_QUIESCENCE=NOT_VERIFIED
G5_FULL=BLOCKED
G7_REPLAY_AND_SCAN=NOT_AUTHORIZED
NO_WRITES_BY_THIS_TOOL=TRUE
OPERATOR_EXIT_CODE=2
NO_AUTOMATIC_RETRY=TRUE
```

**Permission consumed.** Original source/review `rails_calendar_rc0551f_c21b_review_20261117` and historical scratch `rails_calendar_r04_restore_20261121t231331z_27407` were observed through no more than six fixed local Unix-socket PG16 read-only SELECT statements. Two per-DB identity checks surrounded one per-DB aggregate check. Only integer totals and orphan-blob indicators were evaluated privately by the operator. It printed no raw counts, IDs, blob keys, filenames, client data or SQL. `exit 2` is intentional release denial. No further SELECT permission survives.

**Scope and caveat:** `AGGREGATE_PARITY` at immutable SHA `a35bf49` means the 7 aggregate categories were numerically equal in the two databases and the counted orphan attachment/variant references and blank blob-key anomalies were zero. It does **not** prove the underlying blob-key sets, blob-key-to-file correspondence, polymorphic target existence, tenant lineage, source snapshot identity, or full schema types/FKs/index key order. In the *historical a35 code*, equal **positive** `nonlocal_blobs` values would still permit `AGGREGATE_PARITY`. Their actual values were not printed and cannot be recovered without a separately approved new query. **Do not infer `nonlocal_blobs=0`.**

## Synthetic-only safety correction (does not reinterpret past owner DB)

The new pure `ActiveStorageReferenceProbe.assess` contract treats any positive `nonlocal_blobs` on either database as a `DELTA_REVIEW` anomaly, even when counts are equal. Added synthetic tests for equal-positive, one-sided-positive and invalid over-count. This changes the interpretation only in FUTURE executions of the new SHA. It does not retroactively prove actual prior `nonlocal_blobs` values or authorize rerunning C2.3b7s. No database access, migration, media or replay is authorized.

## Next G5: typed schema and constraint-definition acceptance (new approval later)

Existing C2.3b7n 17-table **minimum** catalog PASS only checked presence of columns, validated single-column FK targets, index names/uniqueness/valid-ready and named CHECK presence, plus required migration versions. Before six-family historical scan, require an independently reviewed one-shot **PG16 scratch metadata-only** check for selected column PostgreSQL types and `attnotnull`, FK convalidated+actual target keys, index key order/uniqueness/validity and predicate, CHECK convalidated plus expressions, and exact migration lineage. Use fixed allowlisted `pg_catalog`/`schema_migrations.version` only; no application rows or customer data, no writes. Build pure static expected-value spec from actual committed migrations and synthetic CI test BEFORE proposing executable local query. A positive catalog check still cannot prove row-level tenant isolation or owner authorization.

## Next G6: true writer/tenant/ACL isolation

- Past port 3001/3002 and local short-process scans saw no listeners at one instant. C2.3b7s per-database `pg_stat_activity` observed zero other sessions during its identity checks. Neither proves durable quiescence, separate physical instance, no scheduler reconnect, or the effective Rails connection/role.
- Require separate environment scope and least-privilege proof before any historical source-row scan. Note local `gor` PostgreSQL role was historically `rolsuper=true`: a read-only transaction protects the observed command but does not constitute least-privilege access. Do not downgrade/change the role or move databases without a separate approved migration plan.
- Tenant scope, polymorphic references and source-to-scratch cohort parity are still OPEN. Prove with no-PII aggregate/ACL tests and separately approved bounded owner-specific read-only sampling, never full customer-row export or raw-ID logging.

## DoD and next operator decision

`G3_R04_ARCHIVE_SHA_FORMAT=PASS`, `G4_R04_MEDIA_TREE=MATCH_AT_INSTANT`, `G4_ACTIVE_STORAGE_AGGREGATES=PARITY_AT_INSTANT`, `G4_BLOB_KEY_FILE_AND_POLYMORPHIC_LINKS=NOT_PROVED`, `G5_MIN_CATALOG=PASS`, `G5_FULL=BLOCKED`, `G6_WRITER_QUIESCENCE_TENANT=NOT_VERIFIED`, `G7_SIX_FAMILY_SCAN=NOT_AUTHORIZED`, `REPLAY_WRITER_RELEASE=NOT_AUTHORIZED`.

Next: offline build an exact G5 type/index/FK metadata contract and CI checks, then request a **new specific one-shot owner approval** for a distinct bounded metadata-only scratch read. Preserve all source/scratch DBs, dirty schema, worktrees, archives, mediatrees and Railway. No automatic repeat of any C2.3b7j/k/l/n/q/r/s one-shot action.