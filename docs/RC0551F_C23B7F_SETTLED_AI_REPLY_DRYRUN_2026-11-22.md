# C2.3b7f — Settled AI reply backfill dry-run, no writer

**2026-11-22 · Draft [PR #81](https://github.com/TheGor-365/rails_calendar/pull/81) · CODE + CI VERIFIED (READ-ONLY, synthetic GitHub Actions).** Exact feature SHA [2f19da9fbd81184671d451e4d60339b42f91f206](https://github.com/TheGor-365/rails_calendar/commit/2f19da9fbd81184671d451e4d60339b42f91f206). No HTTP route, scheduler, replay, backfill mutation, paid AI call or user database access.

## Source identity and authority

- Owner identity comes from persisted User/Workspace through DomainOutbox::OperatorAccess.workspace_for!. Sources are scoped to the authenticated workspace through OwnerAiMessage -> OwnerAiConversation, then metadata-only LEFT JOIN to AiSpendEntry -> ProfessionalProfile. No client-supplied owner/workspace identifiers.
- Eligibility: role assistant; state settled; positive message.sequence; linked persisted same-workspace settled ledger; ledger.project_intake_id NULL; permitted OwnerAi::Composer::VERSION or OwnerAi::ConversationResponder::VERSION; nonnegative integer charged_ticks; chronological source/ledger metadata. Unsettled/owner/pending/failed/uncertain/foreign-ledger rows are counted ineligible, not reparable.
- Outbox identity: source_type OwnerAiMessage, source_id message.id, source_version message.sequence, kind ai_reply_saved, workspace owner. Activity identity: event_key OwnerAiMessage:<id>:ai_reply_saved, subject type/id and kind match, metadata empty, same workspace.
- Migrations/current schema checked: 20261113213000, 20261114003000 (professional-profile ledger extension), 20261117030000 (AI conversations/messages), 20261118233000 (reversible conversation removal), 20261121003000 (outbox), 20261121120000 (ActivityEvent); message, ledger, outbox and recorder models read at HEAD 8a0288a. **No immutable original settlement timestamp exists as a separate OwnerAiMessage column.**

## Time: no invented historical settlement

Both callback-created outbox and ActivityEvent store occurrence at settlement. Later OwnerAiMessage.body edits are legal and change updated_at **without another** event, as existing model test proves. The scanner compares surviving historical outbox and ActivityEvent occurrence timestamps, not equality with current mutable updated_at. Current updated_at is only an upper plausibility bound. Source creation/ledger creation/resolution form further plausibility bounds. Two saved occurrences must agree at existing seconds precision.

Presence classifications are exclusive: already_indexed, projection_only, envelope_only, missing_both, inconsistent_records, ineligible_sources. Unexpected artifacts add an overlapping unexpected_artifacts count. When neither projection survives, the original time is not provable: missing_both PLUS overlapping manual_review_required. Unexpected or invalid source version, kind, subject, metadata or time means inconsistent_records PLUS manual_review_required. A single surviving timestamp is *observed* but does not grant a future writer permission. **No category is automatic backfill approval.**

## Query limits, privacy and tests

Code: app/services/domain_outbox/settled_ai_reply_backfill_dry_run.rb. Test: test/services/domain_outbox/settled_ai_reply_backfill_dry_run_test.rb.

Only internal IDs, role/state/version, workspace/profile association, ledger status/operation/charged ticks and timestamps, and outbox/ActivityEvent identity/time/empty metadata are SELECTed by bounded pluck. Neither message.body nor the ledger.result, usage, request_digest, provider_response_id, files, private URLs or client text are read or logged. Output includes only source_type, inspected, category counters, has_more, scan_budget_exhausted and opaque next_cursor. No source IDs or financial IDs are exposed.

Integer 1–25 source rows per page, maximum 250 sources per encrypted cursor chain, initial tenant-scoped MAX(id) ceiling, ordered keyset pagination, AES-256-GCM 15-minute purpose-bound cursor tied to owner, workspace and source family; no automatic renewal and no cross-page consistent snapshot claim. Preview is SELECT-only. Synthetic setup alters ephemeral CI fixtures only; assertions verify zero writes DURING preview to OwnerAiMessage, AiSpendEntry, DomainOutboxEvent, ActivityEvent and OwnerOutboxReplayRun.

Coverage includes settled reply and all four presence states, later body edits, foreign workspace/profile, owner/pending/failed/uncertain, unsupported ledger operation, uncertain ledger status, missing charged ticks, version drift, timestamp/metadata drift, contradictory kind, invalid actor/limit, wrong/foreign/tampered cursors, 25/250 budget and first-page ceiling.

## Exact-SHA evidence and prior failures

**Accepted feature SHA:** [2f19da9](https://github.com/TheGor-365/rails_calendar/commit/2f19da9fbd81184671d451e4d60339b42f91f206).
- [Rails CI #45063473150](https://github.com/TheGor-365/rails_calendar/actions/runs/45063473150) **SUCCESS**: 466 model/controller runs / 7131 assertions; 49 Chrome system runs / 755 assertions; PG18 fresh-schema and deployed-upgrade jobs **SUCCESS**.
- [Security Audit #45063473128](https://github.com/TheGor-365/rails_calendar/actions/runs/45063473128) **SUCCESS**: Ruby dependency audit, static analysis and JS audit.
- Earlier SHA 775f3f6 model tests FAILED because a negative fixture tried to create an unsupported outbox kind and direct-created synthetic settled ledger had a resolved_at before its database-created created_at by microseconds. SHA fd1d315 fixed the negative fixture but still FAILED due to the timestamp setup. Correction 2f19da9 uses a direct-created synthetic settled ledger without a fabricated resolution transition, matching pre-existing outbox tests. No real ledger validation rule was weakened.

This stage does **not** approve local scratch/review migration, any historical data scan, source writes, actual backfill, owner-only HTTP POST, supervised replay, Railway deployment, production merge, paid AI or cleanup of protected local schema/backups.

**Next:** cross-family bounded operator-run read-only reconciliation with explicit pace/resume/manual continuation, source mutation between pages, anomaly classification and before/after report. Any writer requires an independent owner-approved data/backup/privacy gate. C2.2 local role/browser QA is separate and unfinished. This documentation-only commit has its own CI gate.
