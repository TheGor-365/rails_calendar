# RC-036 Stage 3 Slice J — isolated maintenance tick and paginated S3 reconciliation

Date: 2026-11-11, Rails Calendar Draft PR #36. **Synthetic local test/development only.** No public scheduler, cloud service, payments, production release, real client data or backup exercise.

## What is implemented

1. **Maintenance run ledger** in PostgreSQL, \`studio_maintenance_runs\`, scoped to workspace. Unique \`(workspace_id, kind, slot)\`, terminal append-only status, generic \`operation_failed\` (no exception message), and explicitly selected numeric/boolean result counters (no raw object keys, tokens, credentials or names). Scope: health, scan, retention, inventory.

2. **One manual tick per schedule slot.** \`Studio::SourceMaintenanceScheduler\` encodes intervals (health/scan every 5m; retention hourly; inventory daily). Claim is serialized by workspace PostgreSQL row lock. Duplicate ticks in same slot return the same record instead of repeating side effects. A running claim from a crashed/ambiguous process **blocks future claims of that kind**, even if hours have elapsed; no stale-lock takeover or unsafe automatic side-effect replay. An operator must diagnose and reconcile before any future recovery flow. Failed runs are terminal and do not retry automatically.

3. **Explicit physical retention gate.** A maintenance tick cannot delete even expired files unless Rails environment is \`development\`, \`RC_STUDIO_ALLOW_LOCAL_PURGE=true\` and \`allow_retention: true\` were explicitly supplied. This invokes the already owner-gated and HEAD-confirmed sweeper for a bounded batch of 20. Default tick performs only health diagnostics. There is **no orphan-object deletion path**.

4. **Complete-per-budget paginated reconciliation.** \`Studio::SourceInventoryReconciliation\` pages S3 ListObjectsV2 over \`q/\` using continuation tokens with cycle/empty/overlong token protection. Pages have maximum 100 objects, at most 25 pages per call; separately HEAD-checks up to 2500 active DB object keys belonging to the selected workspace. Global DB-key lookup *per page* prevents another workspace's object being labeled as orphan. Unreferenced objects newer than 2 hours are presumed possible inflight uploads, not deletion candidates; older ones are **manual review candidates only**.

5. Reconciliation output reports \`list_complete\`, \`db_complete\`, \`reconciliation_complete\`, \`snapshot_consistent=false\` and separate counts for foreign objects, suspicious old unknown objects, missing active DB-linked objects and HEAD errors. If any page/HEAD budget is exhausted, the result is explicitly incomplete. It contains NO keys, filenames or client data. Provider errors/malformed cursors fail closed, not clean. The listing and DB queries occur at different times: even \`reconciliation_complete=true\` is **not a transactionally consistent snapshot and is not authorization to delete any object**.

## Local operator procedure (run once, never automatic)

Ensure your synthetic test/development workspace, local database and ClamAV simulator are configured. On a trusted developer machine only:

    export RAILS_ENV=development
    export RC_STUDIO_SYNTHETIC_STORAGE=true
    export RC_STUDIO_LOCAL_MAINTENANCE_TICK=true
    export RC_STUDIO_MAINTENANCE_WORKSPACE_ID=<synthetic workspace ID>
    export RC_STUDIO_MAINTENANCE_KIND=health
    bin/rc036-maintenance-tick

Possible kinds: \`health\`, \`scan\`, \`retention\`, \`inventory\`. An inventory tick requires separate dedicated synthetic S3 config including the private HTTPS endpoint, account credentials injected only through private environment, \`RC_STUDIO_S3_PURPOSE=nonproduction-synthetic\`, and \`RC_STUDIO_QUARANTINE_BACKEND=s3\`. The retention tick also requires the separate \`RC_STUDIO_ALLOW_LOCAL_PURGE=true\` flag. Keep it false otherwise. These are **one-off manual invocations** and do not install cron/worker/service. Never expose any CLI as HTTP or to untrusted users. Scan consumes synthetic bytes only.

## Negative tests and acceptance

- Unique slot and concurrent idempotency constraints; no repeats of finished slots.
- Unknown operation rejected; owner membership always rechecked.
- Failed run saved without exception text; terminal audit row cannot be edited or destroyed.
- Crashed/running operation blocks a new time slot rather than silently repeating destructive effects.
- Retention explicitly gated and S3 inventory fails on disk backend.
- S3 pagination over multiple pages and entire current workspace DB set within safety limits; other workspace objects counted separately.
- Missing / duplicate / malformed continuation cursor, provider page size violation, network failure, invalid limits fail closed.
- DB limit or page limit exhausted => incomplete, not falsely "fully reconciled".
- Run results only allowlisted aggregate metrics; no sensitive error strings or S3 keys in results.
- Existing CI synthetic EICAR + ephemeral S3 workflow remains in place; NOT an audit of current official FreshClam database.

## Release blockers

- The current logical schedule requires **manual invocation**. No service executes it periodically; there are no external notifications, cron, web UI, uptime SLAs, heartbeat renewals or operator interventions implemented. An ambiguous crashed run is intentionally not retried automatically.
- The reconciliation has hard caps and is not a transactionally consistent snapshot. Large inventories beyond 25 pages/2500 HEAD checks need a separate approved resumable, checkpointed process; even "complete" counts are not deletion authorization.
- Real durable private encrypted S3 and updated official ClamAV signatures have not been provisioned/verified; Railway storage feature/cost limitations remain. No cloud resources or charges created.
- A durable scheduler/alert provider and monthly spend **require explicit provider choice and hard budget cap** before creation.
- Security/privacy/consent, real client identity, full production-grade worker leases and crash recovery, manual staging E2E and release approval remain open. Backups/restore were skipped by owner for this development iteration; recovery unverified.
- Do not merge/deploy RC-036 or turn on paid external AI. RC-037 awaits independent privacy gates.
