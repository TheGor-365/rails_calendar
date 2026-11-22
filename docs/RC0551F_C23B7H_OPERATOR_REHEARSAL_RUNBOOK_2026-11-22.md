# C2.3b7h — isolated reconciliation rehearsal SOP and before/after report contract

**2026-11-22 · Draft PR #81 · PREPARATION ONLY.** This SOP is **not** authorization to connect to the owner's data, start a restore, execute a migration, scan historical tables, activate replay, repair envelopes, send notifications, call a paid AI provider, or deploy. Its accompanying `DomainOutbox::ReconciliationReportContract` is a **pure Ruby, offline, aggregate-only structure checker**, not a DB scanner or approval engine.

## 1. Evidence already established (do not repeat)

- Existing owner terminal evidence on **22 Nov 2026**: old private PG custom archive + media were restored to **one isolated PG16 scratch**, source/scratch core row counts and schema migration sets independently checked, and the sole approved schema migration `20261121003000` applied and independently verified **only in scratch**. See [existing restore runbook](RC0551F_R04_EXISTING_ARCHIVE_RESTORE_RUNBOOK_2026-11-22.md), [R0.4c4 scratch migration evidence](RC0551F_R04_SCRATCH_OUTBOX_MIGRATION_GATE_2026-11-22.md).
- This restored scratch is a **historical snapshot** and has only the verified outbox migration at that checkpoint. It has **NOT** been confirmed schema-compatible with the six later C2.3b7a–g scanners (ActivityEvent, newer relationships, settled AI reply and publication provenance); it cannot be silently reused as an accepted all-family rehearsal target.
- Remote feature [functional C2.3b7g SHA `8b20236c`](https://github.com/TheGor-365/rails_calendar/commit/8b20236c29a67c838568ee068603a35afef4bd7f) has synthetic [Rails CI #45066438568](https://github.com/TheGor-365/rails_calendar/actions/runs/45066438568) and [Security Audit #45066438546](https://github.com/TheGor-365/rails_calendar/actions/runs/45066438546) SUCCESS. [Current execution status](RAILS_CALENDAR_EXECUTION_STATUS.md) must be read at live HEAD. Automated CI is **not** proof of owner-local data or backup validity.
- Original checkout and its modified `db/schema.rb`, owner review DB, private archives, PG16 scratch and Railway are protected. **Do not rerun previously approved one-time writer**, restore, create scratch, reset schema or clean anything by analogy.

## 2. Pre-operation go/no-go matrix (all independent evidence)

| Gate | Required private operator evidence | Fail condition / action |
|---|---|---|
| G0: exact change | Current PR HEAD, corresponding Rails+Security CI, pinned code and migration blobs, pristine *separate* worktree; original checkout not overwritten | Head drift, dirty original, unknown binaries -> STOP |
| G1: written authority | Owner names exact isolated target, source cohort, permitted read-only commands and limits, purpose, time-window; distinct approval for *any later writer* | No explicit owner approval -> PREPARATION ONLY |
| G2: environment isolation | Independent PostgreSQL instance/endpoint identity and network isolation, verified nonproduction role, no Railway/live backend, exact effective Rails connection, private local credentials | No independent target proof -> STOP; a `rc_restore_` prefix is not proof |
| G3: backup material | Restricted owner-private PG custom dump, full private Active Storage/media archive, separately recorded SHA-256, `pg_restore --list` and format-parser check, timestamps, schema version, tested readability | Partial/old dump, checksum drift, missing media or non-private storage -> STOP |
| G4: **actual isolated restore** | *Separate authorized* creation+restore of a new disposable target; read-only independent parity of core row counts, primary keys, `schema_migrations`, attachments+file hashes, FK/constraints and no extra source writes | Successful preflight or CI/mock alone NEVER suffices |
| G5: compatibility | Compare all six source tables, all referenced joins, `domain_outbox_events`, `activity_events`, expected columns and migration versions against **exact** scanner SHA | Old R0.4 scratch schema insufficient -> STOP; no blind migration |
| G6: quiescence/privacy | Confirm stopped application workers/uploads/provider traffic, restore/storage isolation, least-privileged role, logs redact IDs/secrets, no snapshots shared to GitHub/Drive/Notion/ClickUp | Writers present or logs may include PII -> STOP |
| G7: scan and reporting budget | Plan owner-scoped 1..25 source rows per call; max 250 rows per source family; min 2 seconds between calls; 15-minute total cursor validity; secure in-memory continuation and STOP handling | Cannot complete safely, budget exhausted, expired token or mutation error -> mark INCOMPLETE/MANUAL_REVIEW |

G3 and G4 **cannot be marked verified by the new report-contract code**, metadata from prior checkpoints, or tests. `bin/rc-staging-restore-preflight` is an existing **read-only** archive/absent-target check only; it does not restore, authorize one, or prove host isolation. Use it only if a **new specifically approved independent target** has been identified and its exact prerequisites reconfirmed. This runbook introduces no restore command or new writer.

## 3. Separation of evidence and permissions

The present C2.3b7h task authorizes only a Markdown SOP and offline synthetic checks. There are three strictly separate future operations:

1. **Sandbox creation and restore**, authorized against one exact empty, isolated endpoint after G0–G3. The old independently verified R0.4 scratch is retained rather than reset.
2. **Historical READ-ONLY cross-family scan**, separately authorized only after G0–G6 and all six schema prerequisites pass. All scans are explicit owner/workspace scoped, one page at a time and no shared cursor logging. No HTTP route or scheduled job exists. A `CrossFamilyBackfillDryRun.preview` call is not approved merely because it is SELECT-only.
3. **Any corrective writer / before-and-after post-write validation**, a wholly new review with independent owner authority, transaction/rollback design, idempotency, source immutability, backup consistency, retention/privacy and an exact write-set diff. There is currently **no approved historical backfill writer**.

Do not run unpinned local `rails db:prepare`, `db:migrate`, `db:schema:load`, `pg_restore -d`, `dropdb`, `pg_dump`, replay worker, Rake backfill, background job, production POST or a loop over source families as part of this preparation. The previous scratch migration signoff was **one-time** and does not extend to anything here.

## 4. Read-only rehearsal protocol — DESIGN, not an execution instruction

Upon **future independent approval only**, the operator must record a private decision reference and identify exact source, isolated target and current code SHA. Confirm effective read-only Rails database session and that the owner identity belongs to the intended sandbox workspace; never accept caller-provided workspace ID, and do not pass credentials or personal identifiers into report output.

For each explicitly invoked page of `DomainOutbox::CrossFamilyBackfillDryRun.preview(owner:, limit:, cursor:)`:

1. Collect `source_type`, `family_number`, `inspected`, `page_counts`, `report`, `has_more_in_family`, `family_budget_exhausted`, `completed` and a **locally held** opaque cursor. Do **not** print/share the encrypted cursor, source IDs, body, prompts or token/financial fields.
2. A human initiates the next call only after the 2-second minimum. Stop at 15-minute expiry, 250-per-family budget, owner/tenant mismatch or any malformed state. Do not automatically renew a cursor or restart a scan with a new ceiling to hide incompleteness.
3. On `source or projection changed between pages`, stop and mark **DRIFT / manual review**; the guard covers only the previously read prefix, not a global snapshot. On `missing_both`, `inconsistent_records`, `ineligible_sources`, `unexpected_artifacts` or `manual_review_required`, record aggregate counts; **never repair automatically**.
4. Invitation `expected_transitions` is a count of events, not invitations; source counts are `inspected` (adapted from `inspected_invitations`). Some counters overlap by design; do not incorrectly total overlaps as distinct sources.
5. A final `completed: true` means the ordered six-family traversal reached the end. It does **not** prove every family was fully covered when `budget_exhausted` is true, no source changed outside observed prefixes, or that snapshots were consistent.

The historical settled AI `missing_both` case requires a separate human decision: do not infer a settlement timestamp from mutable `OwnerAiMessage.updated_at`. Capture no message bodies or money details.

## 5. Offline redacted report contract (synthetic proof, not DB attestation)

Implemented in `lib/domain_outbox/reconciliation_report_contract.rb`, with hermetic model-free logic verified through `test/lib/domain_outbox/reconciliation_report_contract_test.rb`. The contract accepts **in-memory hashes** only. It makes no DB/network/IO calls and cannot prove archive integrity, authorization, source lineage or a real restore.

A report snapshot must have **only** these keys:
- `schema_version=1`, `phase="before"|"after"`, `environment="offline_synthetic"|"isolated_sandbox"`.
- `code_sha` (40 lower-case hex), `cohort_digest` (64 lower-case hex **operator supplied, NOT independently verified**), `run_reference` (opaque safe string), `scan_finished` (boolean).
- `families`: exactly six in canonical source-family order, each with `source_type`, `inspected` (0..250), `budget_exhausted`, nine **nonnegative integer** aggregate counts: `already_indexed`, `projection_only`, `envelope_only`, `missing_both`, `inconsistent_records`, `ineligible_sources`, `unexpected_artifacts`, `manual_review_required`, `expected_transitions`.

Unknown keys fail closed: never include source/workspace/user IDs, token digests, private content, SQL, IPs, archive paths, file titles, cursors or full raw logs in the shared report. For normal five source families the mutually exclusive four presence buckets plus inconsistent/ineligible must equal `inspected`; for invitations, presence+inconsistent must equal `expected_transitions`, and `ineligible_sources` is counted separately against inspected invitations. `unexpected_artifacts` and `manual_review_required` can overlap; no double-counting as distinct sources.

`ReconciliationReportContract.compare!(before:, after:)` rejects a mismatched code SHA, environment, supplied cohort digest, source/transition cardinalities, incomplete scan or exhausted family budget. If structurally comparable, it returns per-family count **deltas**, the observed remaining anomalies, a regression/manual-review flag and `verdict="OBSERVATIONAL_DELTA_ONLY"`. It ALWAYS returns `release_approved=false`, `writer_authorized=false`, `independently_verified_backup_restore=false`, `independently_verified_cohort=false`, `cohort_reference_verified=false`. **Matching an operator-provided digest is not proof that exact source row IDs/versions were identical; an independent cohort attestation is absent.** No automatic claim of recovery success or commercial readiness.

### Example evidence interpretation (numbers intentionally fictional)

| Source family | Before | After | Interpretation |
|---|---|---|---|
| `ProjectIntake` | indexed 8, missing 2 | indexed 10, missing 0 | Observed delta indexed +2 / missing −2 **only**, not proof of a legitimate or authorized write |
| `ClientRequestInvitation` | 4 invitations, 7 expected transitions | same 4 invitations, same 7 expected transitions | Compare event counters against **7**, not against 4 |
| `OwnerAiMessage` | missing both 1, manual review 1 | same | Retain manual-review STOP; do not invent settlement chronology |

This is an illustration, **not** a generated report from any user's database. No real "after" snapshot currently exists.

## 6. Triage and STOP decision table

| Observation | Operator disposition | Allowed next action |
|---|---|---|
| no artifacts `missing_both` | MISSING / unproven provenance | count and manually classify, not autofill |
| one-sided `projection_only` / `envelope_only` | OBSERVED / not repair-approved | investigate source lineage and immutable timestamp |
| wrong kind, version, timestamp, foreign ancestry | INCONSISTENT / privacy hazard | quarantine for manual inspection; never retry blindly |
| invitation unexpected transition | UNEXPECTED ARTIFACT | compare canonical timestamp/kind; never invent claim/revoke |
| settled AI missing both | UNRECOVERABLE SETTLEMENT TIME | keep manual review; no mutable-time substitution |
| cursor expired, changed prefix or partial page | DRIFT/INCOMPLETE | STOP; do not claim comparable before/after |
| cap 250 reached with more data | PARTIAL COVERAGE | preserve aggregate report and request new scoped decision |
| any disputed backup or restore parity | BACKUP GATE BLOCKED | no scanning or writer until owner-private investigation |

## 7. Before/after acceptance is a separate future milestone

Before actual writes: independent immutable cohort enumeration (privately, with no ID export), source status/version/occurred_at correspondence, approved change-set, tested isolated restore and exact rollback plan, reviewers and approval. **After** a specifically approved writer: repeat independent same-cohort read-only verification, prove source totals and versions preserved, no duplicate event_key/source revisions, no new `AiSpendEntry` charge, no provider request or external notification, no foreign workspace leakage, and every expected event/projection identity/timestamp match. Detect off-cohort inserts, expired windows, unexpected source changes, and report exceptions rather than smoothing counts.

An aggregated 0-anomaly comparison by itself cannot certify historical correctness or release. Production merge/deploy remains contingent on manual C2.2 browser QA, durable private storage, privacy/ACL, backup/restore and explicit release approval.

## 8. Completion criterion for C2.3b7h preparation

- [x] Inspect latest six-family scanner and prior owner-terminal R0.4 restore/migration evidence.
- [x] Publish no-execution runbook, go/no-go matrix, anomaly routing and report shape.
- [x] Add model-free pure Ruby aggregate report validator/comparator and hermetic negative synthetic tests.
- [ ] Verify exact feature SHA Rails CI / Security Audit; update canonical execution status with links.
- [ ] Separate owner approval for any isolated non-synthetic DB restore, read-only historical scan or writer.
- [ ] Independent same-cohort and backup/restore attestation; real before/after; manual C2.2 QA; release/production gates.

**Next safe stage after CODE+CI VERIFIED:** design a *non-executable*, operator-reviewed sandbox acceptance checklist with current six-family schema inventory and independently verifiable restore/media parity. Do not confuse this SOP with permission to run it.
