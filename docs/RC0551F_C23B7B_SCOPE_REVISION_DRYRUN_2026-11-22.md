# C2.3b7b — IntakeScopeRevision immutable version dry-run (READ-ONLY)

**Date:** 2026-11-22 | Draft [PR #81](https://github.com/TheGor-365/rails_calendar/pull/81). **Status:** CODE + CI VERIFIED (READ-ONLY scope-revision first slice). NO BACKFILL WRITES.

## Authoritative existing contract

- `IntakeScopeRevision` is append-only, belongs to `ProjectIntake`, has positive unique `version` per intake, `author_role` owner/client, `created_at` and private 12-section `answers`. Its `after_create` enqueues `DomainOutboxEvent.enqueue_scope_revision!` only if source has persisted owning intake/workspace and a supported author role. Its `after_create_commit` records `ActivityEvent` `scope_revision_saved` with metadata `{version: revision.version}`.
- Outbox source envelope: `source_type=IntakeScopeRevision`, `source_id=<immutable revision primary key>`, `source_version=<revision.version>`, `kind=scope_revision_saved`, `occurred_at=<revision.created_at>`. Activity event key: `IntakeScopeRevision:<revision_id>:scope_revision_saved`; metadata version and event timestamp must match. A revision v2 is NOT a replacement for v1, and no answer text may be copied to the diagnostic output.
- Earlier `DomainOutbox::BackfillDryRun` checks only `ProjectIntake` v1. It remains unchanged and CI-verified; scope revision is a new independent, restricted class to avoid changing its current cursor/delivery contract.

## Added code and tests

New `app/services/domain_outbox/scope_revision_backfill_dry_run.rb` and synthetic tests introduced in [commit `f5d1817`](https://github.com/TheGor-365/rails_calendar/commit/f5d18173d868b723eb58ba01839de11e1716a0b3), with [fixture/test correction `73e608a`](https://github.com/TheGor-365/rails_calendar/commit/73e608afa085931237b5b01412258c2f35add50e). Server method `DomainOutbox::ScopeRevisionBackfillDryRun.preview(owner:,limit:,cursor:)` uses verified persisted owner-workspace authority and a JOIN to its `ProjectIntake` only, not an arbitrary workspace parameter.

Each page reads ONLY bounded database identifiers, version, author role and created_at, plus matching outbox identity/version/occurred_at and matching activity key/subject/kind/metadata version/occurred_at. No answers/titles/prompts/client content are plucked. Compare timestamp at second precision, matching existing Replayer semantics. If an existing envelope carries the wrong version/time, or a projection has mismatched source/type/kind/version/timestamp, count as `inconsistent_records` rather than assuming delivery completeness.

Output is aggregate-only: `source_type`, `inspected`, `already_indexed`, `projection_only`, `envelope_only`, `missing_both`, `inconsistent_records`, `ineligible_sources`, `has_more`, `scan_budget_exhausted`, opaque `next_cursor`. Invalid source metadata is counted in `ineligible_sources` and never assumed recoverable. Strict integer page size 1..25, max 250 sources per cursor chain, 15-minute AES-GCM encrypted purpose-separated cursor bound to owner/workspace/source type with a frozen initial max source ID. It is NOT a consistent transactional snapshot across page boundaries; live source or projection changes can alter counts.

Tests exercise the four source/envelope/projected categories, distinct owner isolation, invalid actor and role, invalid/foreign/source-family cursor, keyset paging and 250-row exhaustion, source_version drift, ActivityEvent metadata version drift, envelope/projection time drift and zero writes during every preview. Synthetic CI tests may alter only their own fictional rows. No test calls external provider. NO app route, job or backfill writer exists.

## Release boundary and follow-up

Functional exact corrected code SHA `73e608a` [Rails CI #45031103806](https://github.com/TheGor-365/rails_calendar/actions/runs/45031103806) **SUCCESS** across model/controller, Chrome and PG18 fresh/deployed-upgrade; [Security #45031103830](https://github.com/TheGor-365/rails_calendar/actions/runs/45031103830) **SUCCESS**. **CI_VERIFIED for private read-only `IntakeScopeRevision` reconciliation in synthetic CI only**; NOT production scan, approval of missing-event repair or real backfill writer. Previous docs SHA `2949d89` Rails #45029051422 and Security #45029051469 SUCCESS.

Remaining C2.3b7: `IntakeRequirementSet` source version/lineage, `ClientRequestInvitation` transition time/version mapping, `ServiceOfferingPublication` immutable published-version authority, `OwnerAiMessage` settled+ledger linkage; independent rate/pacing, resume, before/after evidence, unexpected-row handling and scope-specific operator approval for any actual backfill. Old R0.4c4/c5 scratch DB verification is independent and DOES NOT grant permission to backfill, replay, scan owner data or release an HTTP POST. Original review DB, scratch, private backup, 3 dirty schema files, Railway/main protected.
