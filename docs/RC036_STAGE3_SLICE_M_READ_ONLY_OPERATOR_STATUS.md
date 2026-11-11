# RC-036 Stage 3 Slice M — read-only synthetic operator report

The existing `bin/rc036-studio-operations-audit` now uses `Studio::SourceOperatorDashboard`. It preserves `operational` (queue, retention lag, ClamAV timestamp/PING) and adds scoped aggregate counts of running/failed/abandoned (over 30 min) maintenance runs and incomplete/expired inventory checkpoints. No IDs, object keys, raw cursors, source content, emails or vendor error text are emitted.

There is **no** automatic recovery, replay, orphan deletion, cursor advancement, alert sink or cron. A completed inventory is not a consistent snapshot; no result can authorize deletion. A run left `running` after a crash needs the separate existing human `OperatorRecovery` review and exact typed confirmation.

The same existing local CLI flags apply: `RAILS_ENV=development`, `RC_STUDIO_SYNTHETIC_STORAGE=true`, `RC_STUDIO_LOCAL_OPERATIONS_AUDIT=true`, `RC_STUDIO_AUDIT_WORKSPACE_ID=<synthetic ID>`. No production access. `RC_STUDIO_AUDIT_S3_INVENTORY=true` still optionally runs the separate bounded read-only S3 audit.

Automated tests: owner/tenant isolation, post-revocation denial, aggregate counts, unchanged running/checkpoint states and redaction. The normal Rails CI also invokes `bin/rc036-local-smoke` directly using isolated test PostgreSQL. Exact-head evidence must be checked after the new commit.

Still blocked: owner-machine local test, real browser/mobile 320/390/430, permanent encrypted private storage, actual FreshClam signature provenance, real client identity/consent, production backup+restore and authorization to deploy.
