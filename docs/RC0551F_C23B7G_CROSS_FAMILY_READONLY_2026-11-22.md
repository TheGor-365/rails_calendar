# C2.3b7g — six-family operator-driven READ-ONLY outbox reconciliation

**22 November 2026 | stacked Draft [PR #81](https://github.com/TheGor-365/rails_calendar/pull/81) | CODE + CI VERIFIED (synthetic, read-only).**
Accepted functional [SHA `8b20236c29a67c838568ee068603a35afef4bd7f`](https://github.com/TheGor-365/rails_calendar/commit/8b20236c29a67c838568ee068603a35afef4bd7f); [Rails Calendar CI #45066438568](https://github.com/TheGor-365/rails_calendar/actions/runs/45066438568) **SUCCESS** (472 model/controller tests, 7,190 assertions; 49 Chrome browser tests, 755 assertions; PG18 fresh-schema and deployed-upgrade success). [Security Audit #45066438546](https://github.com/TheGor-365/rails_calendar/actions/runs/45066438546) **SUCCESS** (Ruby dependencies, Brakeman static analysis and JavaScript audit). CI uses ephemeral synthetic database only; **no real owner database inspection or release authorization**.

## What exists

- `app/services/domain_outbox/cross_family_backfill_dry_run.rb`: private `DomainOutbox::CrossFamilyBackfillDryRun.preview(owner:, limit: 25, cursor: nil)` returning *one source-family page* per explicit invocation. This wraps the six previously verified read-only services rather than implementing new backfill writers:
  1. `ProjectIntake` — `BackfillDryRun`.
  2. `IntakeScopeRevision` — `ScopeRevisionBackfillDryRun`.
  3. `IntakeRequirementSet` — `RequirementSetBackfillDryRun`.
  4. `ClientRequestInvitation` — `InvitationTransitionBackfillDryRun`.
  5. `ServiceOfferingPublication` — `PublicationBackfillDryRun`.
  6. `OwnerAiMessage` settled replies — `SettledAiReplyBackfillDryRun`.
- `test/services/domain_outbox/cross_family_backfill_dry_run_test.rb`: synthetic tests for six-family continuation, privacy/read-only behavior, owner and foreign-owner refusal, invalid/tampered/family cursor, pacing/expiry, previously inspected source/outbox/ActivityEvent drift, and invitation count normalization.

## Budget and continuation contract

- `OperatorAccess.workspace_for!` validates the persisted owner and workspace. No caller-supplied workspace ID or unauthenticated route.
- Each call inspects **1..25 source rows** in exactly one family. Each child imposes max **250 source records** and 15-minute encrypted family cursor; the combined cursor has its own owner/workspace/purpose-binding, no extension of the overall 15-minute lifetime, and requires at least **2 seconds** since the previous page. Theoretical ceiling for a completed traversal is six families times 250 = 1,500 source records (fewer if exhausted/empty); it is NOT permission to run on production. No scheduler or automatic retry.
- The child scanner sets a first-page MAX(id) source ceiling, so subsequently inserted higher IDs are excluded from that family's cursor chain. On exhausted family budget with more candidates, mark `budget_exhausted`, move to next family and do NOT silently renew the child scan.
- After each page, the wrapper forms a SHA-256 fingerprint of a bounded **previously scanned prefix**: selected structural metadata and timestamps, associated outbox source identity/version/kind/state/times, and ActivityEvent identity/metadata/time. Before continuing, a mismatch fails closed with an error requiring operator/manual review. The fingerprint is encrypted within the cross-family cursor, not a raw list or export of identifiers.
- This detects changed *previously scanned current-family prefix* on subsequent pages. It is **not a consistent database snapshot**, and does **not** revalidate all earlier families after leaving them. Concurrent source changes outside the inspected prefix or between the last verification and return remain possible. Never interpret the report as proof of a globally stable historical dataset.

## Safe read surface and report

Only relational IDs, role/state/version, lineage, accounting status/charged-ticks, and timestamp metadata are SELECTed; never pull source goals, invitation seed text/token digest, AI message body, prompts, ledger result/usage/digest/provider response IDs or file contents. The encrypted cursor is internal only; public report contains no source IDs or financial IDs.

Each response includes `source_type`, `family_number`, `inspected`, aggregate `page_counts`, `has_more_in_family`, `family_budget_exhausted`, `completed`, `min_resume_seconds`, cumulative per-family `report` and opaque `next_cursor`. Counters: `already_indexed`, `projection_only`, `envelope_only`, `missing_both`, `inconsistent_records`, `ineligible_sources`, `unexpected_artifacts`, `manual_review_required`, plus invitation-specific `expected_transitions`. **Some anomaly counters overlap classification**, and invitation events can exceed inspected invitation count. The invitation adapter maps child `inspected_invitations` and `ineligible_invitations` to common inspected/ineligible counters without dropping `expected_transitions`.

Report is an *observed read-only baseline*, **not a post-write before/after verification** or a writer authorization. For settled AI replies, missing both historical occurrence records still requires manual review; never reconstruct the original settlement time from mutable `OwnerAiMessage.updated_at`.

## CI history and limitations

The initial SHA [`297374843`](https://github.com/TheGor-365/rails_calendar/commit/2973748437631371a096dff000403fc4d333bfce) failed Brakeman's conservative SQL warning and synthetic test timing. [`cae41d2c`](https://github.com/TheGor-365/rails_calendar/commit/cae41d2c40b6a568372f37bee3f903e2e673d536) replaced interpolated SQL column names with typed Arel expressions; Security passed. [`d507dfd7`](https://github.com/TheGor-365/rails_calendar/commit/d507dfd7efe044dae485fe8748abfc23fa0c732c) corrected test travel/block syntax, after which CI revealed the previously existing invitation source-count naming difference. [`85b740e`](https://github.com/TheGor-365/rails_calendar/commit/85b740e05cac82b755e15044fa0747dfbdfad323) adapted `inspected_invitations`; accepted [`8b20236c`](https://github.com/TheGor-365/rails_calendar/commit/8b20236c29a67c838568ee068603a35afef4bd7f) also retains `ineligible_invitations` and adds synthetic invitation transition test. **No security checks, model validation or CI gates were disabled.**

Explicitly **not authorized / not performed**: local/owner/production data scan, real replay/backfill, writer, source mutations, migration, private HTTP POST endpoint, scheduled worker, AI provider request or expense, Railway deploy, main merge, deletion of old assets/backups/dirty `db/schema.rb`.

## Remaining gates

C2.3b7 = **IN PROGRESS** despite six individual read-only source families (C2.3b7a-f) and this combined traversal (C2.3b7g) being CODE+CI VERIFIED. A future owner-approved isolated sandbox rehearsal with validated backup/restore/privacy, bounded actual operator run, snapshot/mutation handling, anomaly escalation, verified before-and-after report and separate backfill writer design/review remains unimplemented/unapproved.

Independent C2.2 manual role/viewport browser acceptance, durable private storage, backups, privacy/ACL and release/merge approval are open. C2.3c deterministic projections and C2.4 reviewed AI actions remain future milestones. This documentation commit must pass its own exact-SHA CI before being called documentation-verified.
