# C2.3b7s — PostgreSQL Active Storage reference/parity preflight (OFFLINE PROPOSAL)

**2026-11-23 | Existing Draft PR #81 | DESIGN ONLY | DATABASE READ NOT AUTHORIZED/NOT EXECUTED.**

## 1. Accepted owner evidence; do not repeat

- C2.3b7n: a separately authorized ONE read-only 17-table scratch catalog and `schema_migrations.version` result returned PASS. G5 remains BLOCKED beyond that minimum. Permission CONSUMED.
- C2.3b7p: owner-private R0.4 archive session and named archive files owner-only; extracted media tree exists; no listeners on ports 3001/3002 and no checked Rails process-name signatures at that instant. This does **not** prove all writers stopped.
- C2.3b7q: owner executed one read-only archive-byte integrity check, SHA256 matched saved `SHA256SUMS` manifest for `review.pgcustom` and `storage.tar`, PG16 `pg_restore --list` and tar `--list` parsed successfully. Consent CONSUMED; no archive reread.
- **C2.3b7r:** owner-terminal `C23B7R_PREFLIGHT=PASS` and `C23B7R_CURRENT_MEDIA_VS_R04_SNAPSHOT=MATCH`, with `G4_DB_ATTACHMENT_PARITY=NOT_VERIFIED`, `G6_WRITER_QUIESCENCE=NOT_VERIFIED`, `SOURCE_OR_DB_QUERIES=NOT_PERFORMED`, `NO_EXPLICIT_FILE_WRITES=TRUE`, `NO_AUTOMATIC_RETRY=TRUE`. This is an instantaneous comparison of the current `~/rails_calendar_ai_c21c/storage` tree against the already extracted historical `media_restore/storage` tree. One-shot C2.3b7r media consent **CONSUMED**; do not repeat.

Historical R0.4b2 already restored SQL+media once and independently checked core tables and migration versions on 22 Nov 2026. Scratch-only outbox/ledger migrations were separately approved on 22 Nov; preserve them. Do not repeat restores/migrations or infer the source DB has the same new tables.

## 2. Why G4 remains open

Tracked [`db/schema.rb`](../db/schema.rb) defines `active_storage_attachments` (`blob_id`, polymorphic `record_type`+`record_id`), `active_storage_blobs` (`key`, `service_name`, `byte_size`) and `active_storage_variant_records`. Tracked [`config/storage.yml`](../config/storage.yml) declares a local Disk root at Rails `storage/`. Those are code/schema definitions only; they do not attest actual rows, all polymorphic referenced records, current Blob disk keys, current source/scratch snapshots or tenant isolation. The owner's local `db/schema.rb` remains modified and must not be reset, overwritten, staged or compared by publicly pasting its raw content.

## 3. Next proposed new read-only operation: distinct explicit owner permission REQUIRED

**Purpose:** one bounded dual-database local PostgreSQL 16 read-only preflight for **aggregate Active Storage relational integrity and safe source/scratch identity**, not a six-family source scan, row export or replay. **Not authorized by C2.3b7r's media consent**.

Fixed targets: source/review `rails_calendar_rc0551f_c21b_review_20261117` and historical scratch `rails_calendar_r04_restore_20261121t231331z_27407`; only local `/var/run/postgresql` socket, port 5432 and role `gor`. Never Railway/remote production. Require independently verified exact DB identity, PostgreSQL 16, read-only transaction, non-root OS `gor`, absent inherited `DATABASE_URL`/PG* config, resource/time limits, fail-closed expected schema, no other source/scratch sessions at check time. Any unexpected target, role, table missing or schema drift -> STOP, do not scan or retry.

Proposed allowlisted SELECTs on **each** exact DB: (a) schema identity/version metadata needed for safe query shape; (b) integer aggregate counts only from `public.active_storage_blobs`, `public.active_storage_attachments`, and optionally `public.active_storage_variant_records` where present; (c) aggregate broken `attachment.blob_id -> blob.id` and variant-to-blob references via a fixed bounded join; (d) optional aggregate structural check on `service_name=local`, missing/duplicate blob keys, but no raw key values or per-record enumeration. **Do not read** filename, blob key, metadata, checksum, record identifiers, owner/workspace IDs, user names, attachments' record_type values or client content into stdout. Need separately review execution plan and size/cost before choosing COUNT/join specifics; treat any unexpected large table as BLOCKED, not as permission for an unbounded scan.

Share **only redacted status flags**: target identity PASS/BLOCKED, `G4_BLOB_ATTACHMENT_COUNTS_AGREE=PASS|DELTA_REVIEW|BLOCKED`, `G4_ORPHAN_BLOB_REFS=ZERO|PRESENT|UNKNOWN`, `G6_DB_OTHER_SESSIONS=ZERO_OBSERVED|PRESENT|UNKNOWN`, `G4_MEDIA_FILE_REFERENCE_PARITY=NOT_PROVED`, `G6_WRITER_QUIESCENCE=NOT_VERIFIED`, `G5_FULL=BLOCKED`, `NO_WRITES=TRUE`. Counts may be kept owner-private; do not publish counts/IDs/digests if they could reveal customer state. Aggregate agreement alone does not prove same original records, matching blob-key file contents, valid polymorphic references or snapshot consistency. Detecting other sessions at one instant cannot establish quiescence.

Before command delivery: independently review the candidate SQL/code for no secret-bearing row projection or unexpected table contents, run synthetic tests under CI only, verify functional code SHA and CI, create a new clean detached worktree if a script is required, then obtain **NEW one-shot owner approval identifying both databases and aggregate columns/queries**. No database read or changes in this documentation step.

## 4. Remaining G0–G7

- G3 protected existing archived artifacts SHA/format: **OWNER_REPORTED_PASS**; manifest provenance and current recoverability are separate.
- G4 historical R0.4b2 SQL/media restore/core table parity: **OLDER SCOPED PASS**; C2.3b7r current media vs historical extracted copy: **MATCH at instant**; Active Storage DB blob/attachment references and snapshot/cohort: **UNVERIFIED**.
- G5 minimum scratch 17-table catalog: **PASS**; full column type/null/index/FK definition and source lineage: **BLOCKED**.
- G6 port and process signatures: **none observed previously**; broader source/scratch sessions, true writers stopped, service/role/ACL/tenant privacy: **UNVERIFIED**.
- G7 bounded six-family dry-run scan: **NOT AUTHORIZED**, no replay/writer/merge/deploy.

**Hard stops:** no `psql`, Rails boot, `pg_dump`, `pg_restore`, tar, media reread, migrations, writes, source scans, backfill, actual replay, backup replacement, worker stop or Railway operations until individually reviewed and authorized. Keep original dirty local checkout and prior named source/scratch/worktrees. Private files/manifest/DB identifiers other than fixed technical names are never uploaded to GitHub, Drive, Notion or AI providers.