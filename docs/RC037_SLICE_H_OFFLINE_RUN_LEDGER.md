# RC-037 Slice H — immutable synthetic offline run ledger + explicit human review

**Status:** implemented in stacked Draft PR #37. Nonproduction synthetic-only, $0, no external providers or client documents. Final exact-head CI evidence tracked in PR checkpoint.

## Data model and provenance

- `studio_offline_runs`: one explicitly recorded deterministic offline template per project intake, monotonically increasing `version` 1–25. Tenant keys (workspace/client/intake) are bound by PostgreSQL composite FKs; actor is the active owner. Unique `(project_intake_id, version)` plus intake row locking prevents two identical assigned versions. No automatic runs.
- Recorded output is the strictly validated, schema-versioned `OfflineOutputContract` hash: allowlisted purpose, provider `offline_template`, synthetic class, `needs_human_review`, template text (fixed <=512 bytes), zero external calls/tokens/USD, `auto_approved=false`. Also SHA256 of explicitly selected metadata (IDs, hashes, format and size, never source bodies) and HMAC-SHA256 over scope, actor, version, payload and timestamp.
- `studio_offline_run_reviews`: exactly one separate immutable decision per run, either `reviewed_synthetic` or `discarded_synthetic`. Enforced by a unique run FK, with composite tenant-scoped FK, reviewer and HMAC bound to the original run digest. The review event does **not** alter the run or become a client-approved artifact.
- `OfflineRun#verified_payload!` rechecks exact registered template output, data contract, active owner/tenant and HMAC before showing any content; `OfflineRunReview#verify!` rechecks signed review and run. Invalid output is **hidden** on the owner UI with review disabled. Model update/destroy are denied; direct SQL remains a privileged bypass detectable only when signatures differ.

## Explicit owner workflow

1. Open existing AI Settings (test or explicitly opted-in local development only). Configure workspace offline policy and allowlisted purpose; optional restrictive project policy. No external AI or budgets.
2. Click **Generate synthetic offline preview** with 0–10 explicitly chosen scoped metadata-only source IDs. Preview (Slice G) still does not persist. Click **Record this synthetic run for review** separately to append one signed version. Form params do not accept output bytes, model/provider name or cost.
3. In **Recorded offline runs**, inspect the immutable synthetic template and choose **Mark reviewed (synthetic only)** or **Discard synthetic run**. One decision only. A subsequent alternative requires a NEW run. There is no approve-client-document button or client-facing URL.

## Security and acceptance

- All controller methods share nonproduction/test-only hard deny, active owner session, exact `WorkspaceMemory::ProjectIntakeScope` and no-store/nosniff/no-referrer headers. The recorder rechecks policy HMAC audit and zero-cost admission, then pins version creation under a row lock.
- Tests exercise preview-then-record separation, sequential versions, no cost or raw file leakage, forged source IDs, duplicate IDs, cross-client composite DB FKs, revoked and foreign owners, production 404, tamper detection on read, single signed review and duplicate rejection.
- Max 25 saved synthetic runs per intake, 10 shown at once. This is a test-only cap, not production quota or rate billing. No storage encryption claims, paid usage reconciliation, model comparison or actual document drafting.
- HMAC anchored only by Rails app secret is **not independent WORM**: privileged DB + secret holders can rewrite history, DB tail deletion may evade detection without independent anchors/backups. Manual Linux Mint and 320/390/430 browser/accessibility QA, real file storage, updated official antivirus, consent/identity and backup+restore remain unverified.

## Next roadmap

Complete exact-head Rails CI/security audit and owner browser acceptance, then evaluate remaining RC-037 release gates. Do not enable external paid model calls or real source-byte retrieval. RC-038 source normalization/fact provenance should remain a separate Draft PR with synthetic data only until release gates are independently authorized.
