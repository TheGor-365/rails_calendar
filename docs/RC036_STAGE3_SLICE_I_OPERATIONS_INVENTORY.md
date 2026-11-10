# RC-036 Stage 3 Slice I — Read-only operations audit and safe orphan detection

Date: 2026-11-11. Status: synthetic test/local development in existing Draft PR #36. No production deploy, persistent S3, or paid monitoring.

## What is implemented

- Tenant-scoped read-only operational snapshot: queue status counts, due/overdue (>15m) work, oldest due task age, exhausted tasks, failed scans, expired non-revoked quarantine rows, overdue physical retention (>1h), and revoked audit rows. No raw bytes or object keys returned.
- ClamAV daemon protocol readiness with zVERSION database timestamp and zPING. Only returns ready when timestamp is plausible and no older than 96h and ping succeeds; no assertion about official signature provenance or FreshClam effectiveness. Official-signature provenance remains FALSE even for green protocol health.
- After an explicitly authorized manual retention delete, storage existence is verified via HEAD/exist? before audit metadata is marked revoked. A dishonest delete response, still-existing object, or verification error fails closed and does not falsely record physical deletion.
- Strictly read-only S3 inventory for dedicated synthetic nonproduction quarantine: list only q/ with maximum 100 entries and per-tenant HEAD-check a maximum of 100 active DB objects. Output includes counts only and never exports key identifiers or requests object bytes.
- Classification: owned by current workspace, owned by a different workspace (global DB key lookup avoids falsely calling those orphans), older unreferenced (>2h, review candidate only), recent unreferenced/inflight upload, unverifiable timestamp, invalid prefix, and active DB records with missing physical bytes. Truncated results labeled PARTIAL; nontruncated results are BOUNDED SAMPLE, not comprehensive reconciliation.
- No automatic orphan cleanup, no approval to delete candidate objects, no exposed HTTP monitor endpoint, no background scheduler/cron/alert destination, and no cloud resources provisioned.

## Manual local developer audit

Requires a trusted local development session, explicit synthetic storage flags and a synthetic workspace ID. Example environment variables:

    RAILS_ENV=development
    RC_STUDIO_SYNTHETIC_STORAGE=true
    RC_STUDIO_LOCAL_OPERATIONS_AUDIT=true
    RC_STUDIO_AUDIT_WORKSPACE_ID=<synthetic-id>

Run: bin/rc036-studio-operations-audit

Optional S3-only inventory also requires:
    RC_STUDIO_AUDIT_S3_INVENTORY=true
    RC_STUDIO_QUARANTINE_BACKEND=s3
    RC_STUDIO_S3_PURPOSE=nonproduction-synthetic
    RC_STUDIO_S3_ENDPOINT=https://<dedicated-nonproduction-endpoint>
    RC_STUDIO_S3_BUCKET=rc036-<dedicated-synthetic-bucket>
    RC_STUDIO_S3_REGION=<region>
    RC_STUDIO_S3_ACCESS_KEY_ID + RC_STUDIO_S3_SECRET_ACCESS_KEY injected privately, never checked into source

The app validates the dedicated bucket and HTTPS (except CI loopback). Missing/invalid configuration, permission, network failure, or bad owner membership fails closed. S3 read calls can incur provider-request charges if this is ever used against a metered service; do so only under approved budget.

## Interpretation and limitations

1. expired_not_revoked is outstanding metadata, NOT verified physical deletion. An expired queue task does not delete objects until a separately authorized retention sweep runs.
2. Orphan candidates are **review-only**. Files are uploaded before their DB row is persisted. A 2h grace period is a heuristic, never proof sufficient to delete. Unknown keys never deleted automatically.
3. Listing may be truncated, sampled and shared across tenants. The report is counts-only, not exhaustive and not a substitute for independent paginated inventory or reconciliation receipts.
4. S3 HEAD errors must not be interpreted as absent. A post-delete HEAD failure leaves the metadata active for later controlled retry.
5. ClamAV VERSION timestamp and PING verify daemon response only, not official cryptographic AV signature provenance. Prior CI used a single synthetic EICAR signature, not live FreshClam.
6. Physical storage does not exist persistently in CI. Production and paid infrastructure remain untouched.

## Tests

- Queue overdue/exhausted/failed/retention metrics and no sensitive identifiers in output.
- ClamAV version freshness and ping: good, stale, invalid reply.
- Storage exists? truth-check after delete; false-success delete does not revoke metadata.
- Inventory: global tenant key lookup, foreign workspace keys, recent vs old unreferenced, invalid key, missing DB-linked object; truncated list and missing timestamp never treated as clean.
- Invalid S3 purpose, invalid owner membership, network/provider errors fail closed.

## Remaining gates

- Budget/provider/region/privacy/encryption/retention approval before paid resource creation.
- Durable encrypted private S3, live ClamAV with official updated signatures, reliable worker, scheduler/alerts, exhaustive paginated inventory, reviewed deletion receipts and orphan reconciliation across tenancy.
- Real client identity and legal consent review, staging/mobile/browser end-to-end tests and release approval. Backups/restore were explicitly skipped in this development iteration; recovery is unverified.
- RC-037 paid external AI remains off and real client data must not enter the current prototype.
