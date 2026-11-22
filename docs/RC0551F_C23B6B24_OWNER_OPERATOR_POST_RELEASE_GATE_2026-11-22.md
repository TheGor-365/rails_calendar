# C2.3b6b2.4 — Owner-only supervised replay HTTP release contract (NOT ENABLED)

**2026-11-22 | phase `a`: NON-EXECUTABLE POLICY/GET UI only; phase `b`: FUTURE gated POST.**

## Proven preconditions

- The low-level `DomainOutbox::Replayer` is private and bounded. Its delivery is not an owner authorization primitive.
- The service `DomainOutbox::SupervisedReplay` uses `OperatorAccess` and persistent audit run ledger with unique digest, workspace lock, cooldown and fail-closed running state. Its code/PG-connection tests are green, but there is no current authenticated HTTP call path.
- `DomainOutbox::RecoveryInspection` and manual recovery runbook only classify stuck rows for review. Never expire/retry automatically.
- New `DomainOutbox::OperatorConfirmation.validate!` checks authenticated verified owner-workspace, exact HTTP batch string `1/5/10/25` and typed phrase `REPLAY N` without mutations. Translated panel on existing owner GET is informational and contains NO replay action. POST replay route is ABSENT.
- Owner's two LOCAL `db/schema.rb` files are distinct uncommitted contents. Original local review DB is unmigrated for outbox. Scratch only has migration `20261121003000`. New replay audit schema version `20261122130000` is NOT authorized on user DBs.

## Proposed HTTP activation gate — no code enabled at this stage

1. **Preflight:** exact source SHA CI/security green, independent backup & schema/role/tenant safety, explicit separate owner approval of target DB and migration `20261122130000`. Do not `db:prepare`, migrate source review DB or Railway implicitly. Release gate must include rollback plan and manual smoke test.
2. **Session/CSRF:** require an authenticated owner session for every GET/POST, derive workspace from current owner (never accept submitted workspace_id), verify CSRF token using Rails built-in protection, set private/no-store and deny guests, clients, unassigned owners, foreign workspace. Production must use same checks; negative tests must explicitly turn ON `ActionController::Base.allow_forgery_protection` because project test environment normally disables it.
3. **Explicit owner confirmation:** GET remains read-only. A separate POST form (only after approval) must show bounded candidate scope, strict 1/5/10/25 limit, and require exact phrase `REPLAY N`; no replay upon page load, refresh, GET or preflight validation. Only server-generated high-entropy unique request token/nonce can be used to call `SupervisedReplay`; never log/persist raw token or accept arbitrary client-supplied owner/workspace identifiers.
4. **Idempotency/rate:** one run per per-workspace idempotent digest, one running command (DB unique index), cooldown, duplicate and busy states. On a repeated HTTP POST or browser retry, do not run the low-level replayer twice. Distinguish `duplicate`, `busy`, `cooldown`, `failed`, `succeeded` with non-sensitive aggregate response. Never expose event IDs, tokens, request digests, client answers, provider messages or other tenant data.
5. **Concurrency/crash:** synthetic two-connection PG reservation passed; require dedicated CSRF-on and negative role/limit/phrase HTTP tests, browser owner/client/guest/foreign tests, and manual crash-stuck/partial-commit reconciliation before enabling production. No background job or automatic retry/lease take-over; suspected worker still alive = keep blocked.

## Current test contract and blockers

`test/services/domain_outbox/operator_confirmation_test.rb` checks exact accepted/rejected owner/HTTP batch/phrase and zero writes. `test/controllers/owner_outbox_health_controller_test.rb` checks read-only info panel and **no routable POST**. These are NOT CSRF-on, not the owner POST action and not a release. Future tests must explicitly enable forgery protection and exercise real POST with valid/invalid CSRF tokens, replay noop on denied requests, same-token duplicate semantics, two users/tenants, browser refresh, and any failure conditions with audit trail.

**DoD for stage a:** exact-SHA model/controller/Chrome/PG18/Security CI success, source+CI only. **DoD for stage b:** separately authorized DB/release scope, actual POST controller/UI implementation, CSRF-on testing and live role browser acceptance; no silent transition.

## Disabled owner-readiness browser acceptance, stage a

Code [`8655419`](https://github.com/TheGor-365/rails_calendar/commit/86554193bd6b561a26fab6ea4289b6a00938a7d0) adds real Chrome owner 1400/390/320 layout and no-action assertions, plus guest/client denial of the informational panel, and checks unchanged OwnerOutboxReplayRun/DomainOutboxEvent/ActivityEvent/AiSpendEntry counts. This is positive proof only after exact SHA Rails CI #45025611706 succeeds. It does NOT simulate CSRF because the POST route intentionally does not exist. Future stage-b POST must test CSRF with forgery protection explicitly enabled; continue to deny any replay writer before explicit owner release and DB migration approval.

## Pre-POST replay form intent binding — code-only, 22 Nov 2026

New internal `DomainOutbox::OperatorRequestIntent` in [code `b4e0c14`](https://github.com/TheGor-365/rails_calendar/commit/b4e0c1483935e46562932c362e53d8dd8098b604): `prepare!` only when an explicitly authorized future form is prepared, creates a crypto-random 64 lowercase hex token and stores it in Rails session with persisted owner_id, workspace_id, strict allowlisted integer limit and issued_at; `verify!` checks auth-derived workspace via `OperatorConfirmation`, phrase `REPLAY N`, same owner/workspace/limit/token and age 0..10 min using constant-time comparison. Verification intentionally does NOT consume the token: browser duplicate POST within TTL retains the request digest, allowing existing `OwnerOutboxReplayRun` unique key to deny duplicate delivery. A fresh explicit form preparation rotates token. No scheduled generator, read-only GET side effect or DB writer exists at this point. Named replay-token params are filtered from Rails logs. Negative tests synthetic and no-write.

**Release remains blocked:** No owner HTTP POST route, browser submit, CSRF token validation for this action or controller that calls `SupervisedReplay.run!`. Test config disables CSRF by default, so future activation MUST prove valid token/invalid token/missing token with `allow_forgery_protection=true` in isolated tests, and role/session/foreign-workspace denial, duplicates/retry, cooldown and failure response. Only enable when separately authorized new audit migration `20261122130000` on explicitly named DB and reviewed rollback plan. New pre-POST feature SHA `b4e0c14` exact Security #45026196197 **SUCCESS** and Rails CI #45026196199 **SUCCESS** (model/controller, Chrome, PG18 fresh and upgrade). This validates preparation in CI ONLY, not live replay or CSRF-on POST.
