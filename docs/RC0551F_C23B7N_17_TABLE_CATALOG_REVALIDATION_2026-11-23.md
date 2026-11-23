# C2.3b7n — independent PG16 17-table metadata revalidation (PREPARED, NOT AUTHORIZED)

Date: 2026-11-23. Existing Draft PR #81.

## Predecessor evidence

- C2.3b7j owner query reported exactly one name-level missing index from the 17-table minimum contract.
- C2.3b7l owner one-shot query found a valid+ready, nonunique B-tree with ordered keys `(workspace_id, created_at)`, name `idx_on_workspace_id_created_at_2c68e09548`, and no include/predicate/expression. Prior C2.3b7j/b7k/b7l permissions are **CONSUMED**.
- C2.3b7m changes the 17-table name contract to recognize this exact Rails 8.1 generated name (63-byte default exceeds 62-byte limit) plus one legacy alias. Synthetic CI tests verify rejection of arbitrary names and wrong uniqueness.

## New operator: scope

`script/rc0551f_c23b7n_scratch_catalog_readonly.rb` reuses the fixed `DomainOutbox::SixFamilyScratchMetadataProbe::SQL` and corrected static schema contract. ONE read only from `rails_calendar_r04_restore_20261121t231331z_27407` on local PostgreSQL 16 Unix socket using OS+PG role `gor`. The fixed query reads `pg_catalog` entries for exactly the allowlisted **17 public tables** and **only `public.schema_migrations.version`** for migration identity, never application or customer content rows. It checks identity, no other sessions, PG16, readonly transaction, valid+ready catalog indexes, FK, checks, required columns and migration versions.

The operator produces bounded `C2.3B7N_17_TABLE_CATALOG=PASS|BLOCKED` and safe contract-name reasons, then **always** `G5=BLOCKED` and exit code 2. Even metadata PASS does NOT authorize source scans, backfill/replay, writer, DDL/DML, remediation, or production release, and does not independently prove backup/media/tenant/source parity. No raw catalog JSON, SQL error details, PII, tokens or financial records are exposed.

## Current gate and operator instruction

**C2.3b7n = CODE PREPARED OFFLINE, OWNER APPROVAL NOT RECEIVED, LOCAL DB QUERY NOT EXECUTED**.

Before requesting a local command: (1) inspect and verify exact feature SHA and full Rails + Security CI; (2) create and confirm a NEW clean detached worktree pinned to the audited code SHA (never pull or reset the user's older dirty worktrees); (3) obtain **NEW, SEPARATE, EXPLICIT owner consent** to read 17-table catalog metadata AND `schema_migrations.version` **exactly once**. Prior approvals do not transfer. No retry on STOP. No additional DB, media, backups, Railway, provider or live client action.