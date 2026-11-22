# C2.3b6c2.3 — Manual triage of stuck supervised outbox replay

**22 November 2026 | status: SPECIFIED / NO RECOVERY MUTATOR / NOT OPERATOR-ENABLED**

## Scope and permissions

This runbook governs a *future* owner-supervised outbox replay command that has an immutable metadata-only `OwnerOutboxReplayRun` journal with a `running` partial unique index. The local owner source review DB has NOT been migrated for this feature. Scratch DB is verified only for the preceding outbox migration `20261121003000`; the journal migration `20261122130000` is NOT authorized on it. This document does not authorize changing any DB, deploying, sending notifications or calling Grok/AI.

## Detection, not automatic recovery

- Internal `DomainOutbox::RecoveryInspection.snapshot(owner:,now:)` enforces persisted owner-owned workspace and returns safe status + manual_review_required only; no tokens, request digests, row IDs or client data. If no `running` command exists, returns `no_running_command` but NOT an affirmative safety proof.
- A still-running command newer than 15 minutes returns `manual_review_required`; a timestamp in the future also returns review required. This time threshold is only **escalation/triage**, never an expiry, a lease steal or permission to replay.
- The DB partial unique `state='running'` workspace index intentionally denies any other command. Do NOT delete the row, change state, rotate a token, or bypass the guard to 'unblock' it.

## Human incident checklist (read-only until a new owner authorization)

1. **Freeze and identify:** suspend manual operator replay submissions for the specific workspace. Record *environment*, exact DB name/role/socket, app code SHA, UTC incident time, authenticated owner, known request submission context and existing journal state. Preserve audit trail securely; never publish raw token, request_digest, prompts, client content or DB row dumps.
2. **Process evidence:** independently review job/process logs and correlated request/trace information; check running application instances and PG sessions only as supporting evidence. A missing PG session, absence of a web request, or 15-minute wall-clock age **cannot prove** that a worker is dead or that a transaction finished. If active/uncertain: stop, keep the workspace blocked.
3. **State reconciliation:** under a read-only DB session, compare the bounded replay journal and per-workspace outbox states (`pending`/`failed`/`delivered`), attempt counters, due times, unique event keys and existing ActivityEvent projections. Verify no corresponding canonical intake/requirement/service/AI ledger mutation or provider bill; identify whether any delivery may have committed before the journal was marked terminal. Row counts alone are insufficient to prove exact equivalence. Do not inspect cross-workspace or disclose client payloads.
4. **Decision record:** document owner+workspace, code/schema versions, validated query summaries, evidence that no process still executes, suspected delivery progress, and a proposed *one-record, one-workspace* resolution. Have the owner explicitly approve the named database, journal record and exact mutation separately. No blanket permission for `db:migrate`, `db:reset`, retries, rollback, cleanup or Railway.
5. **If approved later:** apply only a reviewed, transactionally bounded resolution with an expected original journal state and immutable actor trail, then independently recheck journal/outbox/projection consistency and current backend activity. Preserve the existing digest for idempotent duplicate behavior. Never auto-trigger replay as part of recovery. If any verification fails, remain fail-closed and escalate.

## Non-goals, invariants and tests

- No automatic expiry/lease takeover, no background scheduler, no generic `UPDATE owner_outbox_replay_runs SET ...`, no production action in this stage.
- No user-visible recovery POST until authenticated owner/CSRF/explicit confirmation, strict rate limits and independent browser owner/client/guest tests pass.
- Never treat `state=failed` as authorization to retry the same source/outbox event; reconcile actual projection/attempt before a new request.
- Read-only tests: owner-only scope, fresh/stale running, clock skew, no running, foreign-workspace denial, zero DB/AI mutations. Two real PostgreSQL connections for command reservation already verified in CI at code SHA `b398bb4`; low-level Replayer is stubbed there, so real production delivery/crash is NOT verified.

## Next accountable step

Check exact feature SHA `7bdcb0c` Rails/Chrome/PG18/Security CI. If green, prepare (still disabled) CSRF-backed owner-only POST design and failure/duplicate response matrix; a separate scoped migration/operation authorization remains necessary before using this in the owner's local or production databases.
