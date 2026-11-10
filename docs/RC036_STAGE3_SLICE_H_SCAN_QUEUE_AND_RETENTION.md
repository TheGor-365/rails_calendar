# RC-036 Stage 3 Slice H — PostgreSQL-backed synthetic scan queue and retention race guard

**Date:** 2026-11-11. **Scope:** Existing Draft PR #36 only. No production deploy, cloud bucket, paid worker, or customer data.

## Why this slice

Previous Slice G established a *local-only* ClamAV/FreshClam configuration and read-only storage preflight. However, the upload controller still scanned files synchronously and retention could race with a scan updating the same audit row. This slice adds a manually driven, bounded PostgreSQL queue (no Redis or new paid services) and serializes scan/retention state transitions using a blob row lock.

## New database object

\`studio_source_scan_tasks\` is a one-task-per-blob record. Composite foreign key guarantees the queued blob belongs to the selected workspace. The table contains no raw bytes, emails, tokens, filenames, or scanner response messages.

States:
- \`queued\`: never processed
- \`retry_wait\`: failed closed; next attempt scheduled after 5 or 30 minutes
- \`complete_clean\`, \`complete_infected\`: terminal scan outcomes
- \`exhausted\`: three unsuccessful attempts (requires manual investigation, no auto-reset)
- \`expired\`: original quarantine TTL expired
- \`cancelled\`: revoked/other terminal blob

A database CHECK caps attempts at 3. A composite scoped FK, unique blob index, and due-task index prevent duplicate and cross-tenant tasks. Terminal task rows are retained for audit; no queue task is automatically reactivated.

## Access and processing

The owner-only nonproduction endpoint is:

\`\`\`http
POST /workspaces/:workspace_id/clients/:client_id/project_intakes/:project_intake_id/sources/:id/queue_scan
\`\`\`

It is explicitly disabled when synthetic storage is disabled. Only the authenticated workspace owner with active membership may queue a staged/failed synthetic blob. The endpoint does **not** scan or download a file.

The local runner is **not a service or cron job**, and runs only when explicitly invoked:

\`\`\`sh
export RAILS_ENV=development
export RC_STUDIO_SYNTHETIC_STORAGE=true
export RC_STUDIO_LOCAL_SCAN_RUNNER=true
export RC_STUDIO_SCAN_WORKSPACE_ID=<numeric-synthetic-workspace-id>
export RC_STUDIO_SCAN_LIMIT=5
# Configure a local UNIX clamd socket or reviewed loopback container first.
bin/rc036-studio-scan-runner
\`\`\`

It refuses production even when flags are set. **It assumes local trusted developer machine access and executes with the selected workspace owner's privileges.** Do not expose this script as a public API or run on a shared untrusted host.

Workers select at most 10 due tasks per invocation with PostgreSQL \`FOR UPDATE SKIP LOCKED\`. Each task remains locked during its small (max 256KiB) file scan; the ClamAV adapter bounds the scanner to 8 seconds. This transaction-holding-I/O design is intentionally restricted to a small-volume *synthetic development* system, not approved for high-throughput or production workers.

A scan error persists \`ProjectSourceBlob.scan_state=failed\`, schedules retry with increasing delay, and never grants a download. Three errors lead to terminal \`exhausted\`. A clean scan still requires exact source SHA256 match, owner ACL, expiry, AV verdict and state-transition guards.

## Concurrency and physical retention

\`ProjectSourcePipeline#scan!\` now obtains an exclusive blob row lock before reading/quarantining the verdict and revalidates membership and TTL **after** scanning, immediately before persisting verdict. \`ProjectSourceRetention#sweep_expired!\` holds the same row lock when deleting expired physical bytes and changing audit metadata to revoked. Thus a successful scan cannot revive an object revoked and deleted by retention while in flight.

The application still does **not** schedule cleanup automatically. Expired queue tasks are terminally marked \`expired\`, but **this only updates queue metadata; it does NOT delete physical bytes**. Physical deletion still requires a separate authorized call to \`ProjectSourceRetention#sweep_expired!\`, with its own monitoring and reconciliation. Missing a retention run remains an operational blocker.

## Negative tests

- No task until owner explicitly queues; duplicate queue requests return the same task.
- Guest/cross-workspace/wrong client ID/intake ID denied.
- Genuine blob bytes stay unavailable before a clean scanner verdict.
- Synthetic \`clean\` / \`infected\`, failed scan, scheduled retry, and exhausted third attempt.
- Attempt count and terminal uniqueness are constrained; composite FK rejects forged cross-tenant task.
- Expired task never scans and separately invoked retention physically deletes object.
- Revoked owner membership disables queue operations.
- Production storage gate prevents queue requests and local runner is explicit development-only.
- Existing S3+ClamAV isolated CI remains a **synthetic EICAR signature** test, not proof of full official signature updates.

## Missing before RC-036 release

- [ ] Agree paid provider and **hard monthly spending cap**. No infrastructure has been created without budget approval.
- [ ] Persist an actual audited private non-production bucket with the necessary encryption, key rotation, access logs and retention/lifecycle.
- [ ] Run ClamAV with updated **official** signature DB and evidence of FreshClam updates.
- [ ] Replace manual local runner with production-designed isolated worker/queue, crash recovery, bounded job lease, retries, dead letter and alerting. Do not use current DB-lock-over-I/O implementation for real clients.
- [ ] Schedule, monitor and reconcile physical retention and orphans; make physical storage deletion independently verifiable.
- [ ] Legal review of client consent/identity, manual staging E2E/mobile/IDOR and security review; explicit merge/deploy approval.
- [ ] Per owner decision, no backup/restore work in this development iteration; recoverability is **unverified**.

**Real client file upload/download and production client authorization remain disabled. Paid/external AI remains off.**
