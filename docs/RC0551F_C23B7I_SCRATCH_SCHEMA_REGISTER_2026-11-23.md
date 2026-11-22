# C2.3b7i — six-family scratch schema compatibility register and independent restore acceptance

**Date: 2026-11-23 · target: Draft PR #81 · evidence level: SOURCE STATIC + CI SYNTHETIC ONLY.**
This is a **preparatory inventory**, not a local scratch audit, not a run instruction, not permission to inspect customer tables, and not evidence that the restored PG16 scratch meets these requirements. Read together with [C2.3b7h operator SOP](RC0551F_C23B7H_OPERATOR_REHEARSAL_RUNBOOK_2026-11-22.md), [R0.4b2 restore checkpoint](RC0551F_R04_EXISTING_ARCHIVE_RESTORE_RUNBOOK_2026-11-22.md), [R0.4c4 one-off migration audit](RC0551F_R04_SCRATCH_OUTBOX_MIGRATION_GATE_2026-11-22.md) and the [canonical execution ledger](RAILS_CALENDAR_EXECUTION_STATUS.md).

## 1. Material schema drift at the current GitHub HEAD

At start of C2.3b7i, live Draft PR #81 HEAD was `6d5c5ebc563c50eb709f786d588cc3495e4dc7d9`: Rails CI #45068733391 and Security #45068733442 both SUCCESS. The tracked `db/schema.rb` at this SHA **does not define** the following FOUR scanner-essential tables:

| Required table | Canonical creation migration committed to PR | Required for |
|---|---|---|
| `intake_scope_revisions` | `20261120120000_create_intake_scope_revisions.rb` | Scope revisions, requirement lineage |
| `intake_requirement_sets` | `20261120183000_create_intake_requirement_sets.rb` | Versioned requirement snapshots |
| `domain_outbox_events` | `20261121003000_create_domain_outbox_events.rb` | ALL six envelope checks |
| `activity_events` | `20261121120000_create_activity_events.rb` | ALL six projection checks |

**Do not blindly load or overwrite `db/schema.rb`** to correct this. Branch migration files are the current committed schema *intention*; actual DB catalogs and `schema_migrations` are evidence of applied schema. Older R0.4 scratch's one separately approved outbox migration (`20261121003000`) does not verify any of the other three table definitions, old/new applied-version alignment or source joins. Its precise present schema and source row state are **UNKNOWN without a separately approved fresh read-only audit**.

## 2. Exact read surface per family

Sources below are from the six child scanners + `CrossFamilyBackfillDryRun::FIELDS` and `source_scope`; shared envelope/projection tables are required for every family. Columns listed are **minimum selected/join/guard columns**, not permission to SELECT whole rows.

| Family | Canonical source and required scope/lineage joins | Minimum identity and state/time columns | Expected event kind / historical version |
|---|---|---|---|
| `ProjectIntake` | `project_intakes.workspace_id = current owner workspace` | `project_intakes.id, workspace_id, status, created_at, updated_at` | `intake_created`, v1 |
| `IntakeScopeRevision` | INNER `project_intakes.id = intake_scope_revisions.project_intake_id`, tenant on intake | `intake_scope_revisions.id, project_intake_id, version, author_role, created_at, updated_at`; intake `workspace_id` | `scope_revision_saved`, source `version` |
| `IntakeRequirementSet` | INNER `project_intakes`; LEFT `intake_scope_revisions` so invalid lineage remains detectable | `intake_requirement_sets.id, project_intake_id, intake_scope_revision_id, version, created_at, updated_at`; revision `id, project_intake_id, version, created_at`; intake `workspace_id` | `requirements_saved`, source `version` (not joined revision version) |
| `ClientRequestInvitation` | Direct `workspace_id`, LEFT `project_intakes` | `id, workspace_id, claimed_at, submitted_at, revoked_at, claimed_by_user_id, project_intake_id, created_at, updated_at`; joined intake `id, workspace_id` | `invitation_issued` v1, `_claimed` v2, `_submitted` v3, `_revoked` v4, **up to four transitions per source** |
| `ServiceOfferingPublication` | INNER `service_offerings.workspace_id`; LEFT `service_offering_versions`; owner matched to workspace owner | publication `id, service_offering_id, service_offering_version_id, owner_user_id, event, created_at, updated_at`; version `id, service_offering_id, approved_at`; offering `workspace_id` | `service_published` or `service_unpublished`, v1; do not infer past state from mutable `published_version_id` |
| `OwnerAiMessage` | INNER `owner_ai_conversations.workspace_id`; LEFT `ai_spend_entries` and `professional_profiles`; owner+settled scope | message `id, owner_ai_conversation_id, role, state, sequence, ai_spend_entry_id, created_at, updated_at`; ledger `id, status, operation, professional_profile_id, project_intake_id, charged_ticks, created_at, updated_at, resolved_at`; profile `workspace_id` | `ai_reply_saved`, source `sequence`; `missing_both` demands manual review; message `updated_at` is **not** proof of immutable settlement time |

**Shared:** `domain_outbox_events` needs `id, workspace_id, source_type, source_id, source_version, kind, occurred_at, state, updated_at`; `activity_events` needs `id, workspace_id, event_key, subject_type, subject_id, kind, occurred_at, metadata, created_at`. `users.id/role` and `workspaces.id/owner_user_id` are required for `OperatorAccess.workspace_for!`. `active_storage_blobs` and `active_storage_attachments` belong to independent **backup/media parity**, not six-family SELECT scans. The public contract enumerates **17 tables**: 15 source/join/ledger/identity/event tables plus 2 private media catalog tables.

**Never fetch**: `project_intakes.goal`, revision `answers`, requirement `requirements`, invitation `token_digest/seed_goal`, service version text, AI message `body`, spending `result/usage/request_digest/provider_response_id`, media filename/key or row contents. Those fields may exist but are intentionally **not** scanner fields.

## 3. Version, index and constraint gates

Static version prerequisites, in chronological order: `20261108120000` workspace ownership, `20261113213000` AI spending, `20261115190000` service offering/publication lineage, `20261117030000` owner conversations/messages, `20261119000500` invitations, `20261120120000` scope, `20261120183000` initial requirements table, `20261120204500` non-unique source lookup for multiple owner review versions, `20261121003000` outbox, `20261121120000` activity. Later migrations can coexist; do not claim a specific target has any version before querying its **own** `schema_migrations` read-only under approved scope.

Named invariants in `lib/domain_outbox/six_family_scratch_schema_contract.rb`:
- Scope: unique `idx_intake_scope_revisions_version`; `chk_intake_scope_version_positive`, `chk_intake_scope_author_role`; FK to intake.
- Requirements: unique `idx_intake_requirement_sets_version` and **non-unique** `idx_intake_requirement_sets_source` (migration `20261120204500` deliberately replaces the original unique source index); `chk_intake_requirement_set_version`; two distinct FKs (intake + revision).
- Invitations: `index_client_request_invitations_on_workspace_id_and_created_at`; `chk_client_invite_claim_triplet` and workspace/intake FKs.
- Publications: `idx_service_offerings_workspace_key` unique, `idx_service_offering_versions_unique` unique, `chk_service_publication_event`, owner/offering/version FKs.
- AI: `idx_owner_ai_message_sequence` unique, `chk_owner_ai_settled_requires_spend`; spending exactly-one-subject + nonnegative ticks; profile+conversation workspace links.
- Outbox: `idx_domain_outbox_source_revision` unique across `workspace_id,source_type,source_id,source_version,kind`; `idx_domain_outbox_delivery_queue`; three named CHECKs for positive source/version, nonnegative attempts and allowed state.
- Activity: `idx_activity_events_workspace_key` unique per workspace, `idx_activity_events_workspace_subject` and `idx_activity_events_workspace_time`; CHECK for kind/event_key nonempty and positive subject ID.
- Backup media: attachment `blob_id -> active_storage_blobs` FK, unique blob key and attachment identity indexes; **these catalog checks do not read/private-verify file bytes**.

A mere column name match is NOT enough for final owner DB acceptance: operator must inspect PostgreSQL types, `attnotnull`, FK `convalidated`, check expression and validation, index `indisvalid/indisready`, unique key column order, ACL, cross-tenant lineage and effective owner scope. The CI test only checks minimum catalog **presence**, FK targets, index names/unique flags, check names and required migration versions on its ephemeral PG15 test DB; it is not a proof of constraint validation or privacy of an actual restore.


**Schema-history correction discovered by actual CI:** the first C2.3b7i code SHA `60bfd9b2` FAILED one new test (not an owner DB failure): the initial inventory wrongly classified `idx_intake_requirement_sets_source` as UNIQUE because the creation migration `20261120183000` contains that constraint. The later committed `20261120204500_allow_requirement_set_review_versions.rb` explicitly **removes and recreates the same named index without UNIQUE**, allowing multiple requirement-set review versions per scope revision. Canonical uniqueness remains `(project_intake_id, version)`. This is a real migration-chain correction: register both versions, require the final index `unique=false`, and add a negative test for incorrectly unique historical lookup. Do not suppress the failing test or change the migrations.

## 4. Fail-closed *future* independent PG16 scratch acceptance

**Current permission: no connection to local PG16, no restore, no scan, no new migrations.** Following steps are acceptance requirements for a later individually authorized, **read-only** operator session and separately approved isolated environments.

1. **Identity and provenance (private):** pin current code/migration Git SHA, original review DB and scratch DB identities, PG16 socket/role/server identity, original private archive/session path, SHA256 ledger, full media manifest and independent owner consent. Confirm target is NOT Railway, source or production; enforce `default_transaction_read_only=on`, no inherited `DATABASE_URL`, no additional active writers. Record only sanitized PASS/BLOCKED markers in shared status. A database prefix or `RAILS_ENV=test` is not isolation proof.
2. **Restore integrity (G3/G4):** existing authorized R0.4b2 archived SQL+storage hashes, SQL TOC and media tar hashes, independent restore-to-scratch comparison are historical **for their original snapshot** and must stay intact. For a *newly approved* restore, check archive and media provenance pre/post copy, DB row/table counts, primary keys and schema_migrations against the exact captured source snapshot **before any approved forward migration**; compare media file digest/size and Active Storage blob/attachment references in private output. Archive checksum + `pg_restore --list` does not prove a usable restore. If source writes were not stopped at capture, reject inconsistent SQL/media.
3. **Schema compatibility (G5):** separately inspect `pg_catalog.pg_attribute`, `pg_constraint`, `pg_index`, `pg_class`, `information_schema.columns` and `schema_migrations` on exact isolated target; compare to the 17-table minimum contract, individual FK/unique/check validations and approved migration chain. Classify each expected column/index/constraint as PRESENT+VALID / MISSING / TYPE-OR-NULL-DRIFT / INVALID / UNKNOWN. **Any UNKNOWN or missing requirement = BLOCKED**, not automatically migrate. The earlier scratch outbox migration PASS is *insufficient* because `activity_events`, scope and requirement presence have not been independently proven.
4. **Preservation and privacy (G4/G6):** independently verify canonical row counts and a private row-key digest/ID-set comparison on same frozen cohort; compare owner workspace scope, source versions, `AiSpendEntry` counts and charges, event provenance, no new foreign workspace links, no user/provider call, and absence of restored media corruption. Do not send raw IDs, paths, digests that encode user data, archive contents, SQL results, passwords or private filenames to GitHub/Drive/Notion/ClickUp.
5. **Assessment:** only if all gates pass AND the owner independently authorizes a bounded read-only six-family scan can the operator proceed to `CrossFamilyBackfillDryRun.preview`. Even a PASS does not authorize replay, backfill writer, restore repeat, migration, production deployment or merge. On any STOP, preserve the old scratch and backups unchanged and raise a scoped review item.

### Proposed private evidence ledger (blank; NOT observed)

| Gate | Expected operator-proof artifact | Status now |
|---|---|---|
| G0 code/current CI | exact feature and docs SHA, both workflows | **C2.3b7i CI pending** until exact run verifies |
| G1 owner permission for new scan | explicit approved read-only target/scope | **NOT GRANTED** |
| G2 isolate PG16 target | independent effective Rails+psql identity and sessions | **NOT RECHECKED for C2.3b7i** |
| G3 historic archive/media | older private checksum/snapshot evidence | **R0.4b2 historical PASS, not revalidated now** |
| G4 old restore parity | existing private source/scratch counts/schema/media proof | **R0.4b2 historical PASS only** |
| G5 six-family schema and constraints | all 17 tables/columns/FK/index/CHECK/types/versions | **UNKNOWN for old scratch** |
| G6 privacy/writers | no unapproved readers/writers, storage/ACL review | **NOT RECHECKED** |
| G7 bounded scan | owner authorization, 1..25/page, 250/family, 2-sec pace, 15-min cursor | **NOT STARTED** |
| Writer/real before-after | separate reviewed change set and independent comparison | **NOT AUTHORIZED** |

## 5. CI-only, non-invasive evidence

The new `DomainOutbox::SixFamilyScratchSchemaContract.violations(catalog)` accepts an **already constructed** catalog Hash (table names, columns, FKs, named index+unique, named CHECK, migration versions) and returns precise missing/invalid requirement labels. It never opens a database, executes SQL or prints rows itself. `test/lib/domain_outbox/six_family_scratch_schema_contract_test.rb` constructs that catalog **only from GitHub Actions' disposable test PostgreSQL** and verifies the live CI schema matches the exact family list and cross-family fingerprint column references. Negative tests remove an event table, missing AI column, migration version, expected FK/CHECK and uniqueness, asserting fail-closed behavior.

Passing CI = CODE-STATIC/CI-TEST SCHEMA VERIFIED, not owner PG16 scratch acceptance. PG18 fresh/upgrade CI jobs establish migration path on **synthetic** GitHub Actions DB, not recovery of owner archives. Do not create a CLI command that connects to scratch in this stage.

## 6. Next accountable action

1. Exact SHA Rails CI + Security Audit for C2.3b7i code (including new test).
2. Commit a new canonical `RAILS_CALENDAR_EXECUTION_STATUS.md` checkpoint and update this SOP with exact-SHA evidence, then verify documentation SHA CI too.
3. Continue with **read-only audit design and owner approval proposal** (exact isolated DB identity, no writes), not real inspection until separately authorized.

**NO EXECUTION OF SOURCE DB, OWNER SCRATCH, PRODUCTION, WRITER, BACKUP, MIGRATION OR REPLAY IN THIS SLICE.**
