# RC-036 Stage 3 Slice K — zero-paid local infrastructure, manual crash review, resumable S3

Date: 2026-11-11. Scope: Draft PR #36, synthetic Rails **development/test only**. No production deploy, public client access, paid storage, paid worker, external SMTP or external AI.

## Practical startup modes

**Mode A — minimum, no S3 or ClamAV required.** Existing Rails/PostgreSQL + local disk-backed synthetic quarantine. Useful for HTTP, queue, permissions and manual maintenance tests. On trusted Linux Mint:

    export RAILS_ENV=development
    export RC_LOCAL_DEV_DATABASE_URL=<existing local development PostgreSQL URL>
    export RC_STUDIO_SYNTHETIC_STORAGE=true
    export RC_STUDIO_QUARANTINE_BACKEND=disk
    bin/rails db:prepare

To get a non-destructive, one-off health report for an *existing synthetic workspace*:

    export RC_STUDIO_LOCAL_MAINTENANCE_TICK=true
    export RC_STUDIO_MAINTENANCE_WORKSPACE_ID=<synthetic workspace ID>
    export RC_STUDIO_MAINTENANCE_KIND=health
    bin/rc036-maintenance-tick

The daemon clock is NOT running; every invocation runs at most one logical slot. Without clamd, health reports AV unavailable. This does not grant permission to upload actual customer files.

**Mode B — optional free local S3 exercise.** Local S3-compatible SILO image pinned to the digest already used by the isolated CI. There is no external account or storage charge. Local disk/RAM usage still applies. Set a fresh synthetic local secret in your shell and keep it out of source control:

    export RC_STUDIO_S3_ACCESS_KEY_ID=rc036synthetic
    export RC_STUDIO_S3_SECRET_ACCESS_KEY="$(openssl rand -hex 24)"
    export RC_STUDIO_QUARANTINE_BACKEND=s3
    export RC_STUDIO_S3_PURPOSE=nonproduction-synthetic
    export RC_STUDIO_S3_ENDPOINT=http://127.0.0.1:9000
    export RC_STUDIO_S3_BUCKET=rc036-local-synthetic
    export RC_STUDIO_S3_REGION=us-east-1
    export RC_STUDIO_LOCAL_S3_HTTP=true
    docker compose -f deploy/rc036/s3-local.compose.yml up -d
    bin/rc036-local-s3-bootstrap

The app accepts **HTTP only to loopback in explicit Rails development** with RC_STUDIO_LOCAL_S3_HTTP=true; public HTTP and production remain denied. Container maps only 127.0.0.1:9000 and stores synthetic objects in a local Docker volume. This is **not** verified encrypted production storage and has no guaranteed lifecycle. Do not put customer files into it.

Optional ClamAV/FreshClam demo exists at deploy/rc036/clamav.compose.yml (loopback 127.0.0.1:3310, more RAM), but **is not required** for the cheapest metadata/queue demonstration. Scan verdicts require a configured real scanner and updated official DB for meaningful malware coverage; synthetic CI tests are not such proof.

## Safe recovery after an abandoned maintenance tick

New append-only studio_operator_reviews with owner ID, workspace, maintenance run, fixed reason code and timestamp, composite DB tenant FK and one review/run uniqueness. No unstructured note or secret input is retained.

The explicit Studio::OperatorRecovery#close_abandoned! requires:
- active workspace owner with real membership; synthetic test or opted-in local development;
- run still in state running, started at least 30 minutes earlier;
- exact typed confirmation REVIEWED-RUN-<id>;
- reason corresponding to the kind: health_inspected, inventory_inspected, scan_tasks_inspected, retention_objects_inspected.

For **scan**, inspect the scan task / blob states before asserting scan_tasks_inspected. For **retention**, inspect actual storage existence and audit metadata before asserting retention_objects_inspected. The program records the **operator's assertion, NOT independent proof**, marks the abandoned run failed, and never repeats its side effects.

Manual CLI example on trusted dev only:

    export RC_STUDIO_OPERATOR_RECOVERY=true
    export RC_STUDIO_REVIEW_WORKSPACE_ID=<synthetic workspace ID>
    export RC_STUDIO_REVIEW_RUN_ID=<blocked run ID>
    export RC_STUDIO_REVIEW_REASON=scan_tasks_inspected
    export RC_STUDIO_REVIEW_CONFIRM=REVIEWED-RUN-<blocked run ID>
    bin/rc036-review-abandoned

The operator may then run a later time slot **manually** after reviewing side effects. There is NO automatic takeover or deletion, even when 30 minutes elapse. Terminal receipts and runs cannot be altered via Rails models; full production incident workflow is not yet in scope.

## Resumable S3 quarantine inventory beyond 25 pages

Studio::SourceInventoryResume persists one active checkpoint/workspace in PostgreSQL. It performs **one S3 page (100 keys max) OR one bounded DB HEAD batch (20 rows)** per invocation. It can continue across new Ruby processes and beyond 25 pages without restarting, up to a hard safety ceiling of 10,000 S3 pages in a 24h checkpoint.

Sensitive continuation tokens are AES-256-GCM authenticated/encrypted with a key derived from the Rails application secret; tokens never appear in CLI output, logs or unencrypted DB columns. Only HMAC cursor digests, allowlisted aggregate counters, numeric last processed blob ID, checkpoint status and an HMAC of the bucket+endpoint+region are stored. Changed S3 configuration, broken ciphertext, cursor loops and unsupported provider replies fail closed; a transient provider failure **does not advance the saved checkpoint**, and a later manual call may retry that same read-only page.

To begin on local synthetic S3:

    export RC_STUDIO_LOCAL_INVENTORY_RESUME=true
    export RC_STUDIO_INVENTORY_WORKSPACE_ID=<synthetic workspace ID>
    export RC_STUDIO_INVENTORY_ACTION=begin
    bin/rc036-inventory-resume

Output provides only a checkpoint ID, counters and status. To process one bounded step:

    export RC_STUDIO_INVENTORY_ACTION=step
    export RC_STUDIO_INVENTORY_CHECKPOINT_ID=<ID from begin>
    bin/rc036-inventory-resume

Repeat step until phase completed. Credentials and raw keys are never printed. A resumed DB pass checks records whose IDs are <= the maximum known at checkpoint creation; changes after that instant are deliberately **not a consistent snapshot**. Even a completed checkpoint is not permission to delete an orphan. Object deletion remains completely separate and requires specific owner-approved synthetic retention. No orphan object is ever automatically deleted.

Expired checkpoint (after 24h) is marked failed and cannot resume; begin will create a new checkpoint. No quiet restart, no automatic recovery of a damaged cursor. If a partial scan is invalidated, investigate and start a new manual checkpoint. Checkpoints and operator decisions are retained for audit.

## Acceptance and missing gates

- [x] Tests for owner isolation, incorrect/missing confirmations, duplicate review, retention-specific review, DB cross-tenant FK, append-only receipt, and accidental replay prevention.
- [x] Tests for multi-page checkpoint persistence across service instances, 27-page resumption beyond the previous 25-page limit, provider retry without progress loss, cursor tampering/repetition, wrong bucket, expiration and wrong tenant.
- [x] Local S3 HTTP accepted only on explicitly opted-in development loopback; remote HTTP and production denied.
- [ ] Not an actual periodic scheduler or cloud worker; no integrated alert transport, durable multi-provider lock lease or human-reviewed automated incident process.
- [ ] Page-by-page inventory is non-atomic under concurrent S3 writes; no object deletions from inventory and no independent cryptographic proof of vendor signatures.
- [ ] Permanent encrypted private bucket, official freshclam running with verified maintained DB and production telemetry remain unprovisioned.
- [ ] Real client identity + legal consent + manual staging E2E + privacy/security review before production launch.
- [ ] Backups/restore intentionally skipped in development; recoverability unverified.

No paid services, subscriptions, merge, Railway production changes, or production client files are involved in this Slice K.
