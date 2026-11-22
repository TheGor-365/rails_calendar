# C2.3b6 supervised replay — checked code and pending safety contracts

**Dated 2026-11-22; Draft PR #81.** Read live GitHub HEAD+CI before editing. Functional code inspected at `36859c3086f6ece81630703145a7e82e8cd56159`, code-equivalent to documentation-only PR head `292c32b`.

## Completed, do not rebuild

- R0.4c4 locally `DB_VERIFIED_SCRATCH` by owner independent PG16 audit (source review DB not migrated); no production or client-facing change.
- `DomainOutboxEvent`: private source-only idempotent envelope unique index, `pending/failed/delivered`, MAX_ATTEMPTS=5, workspace scope.
- `DomainOutbox::Health.snapshot(owner:)/preview(owner:,limit:)`: verified persisted owner workspace, aggregates and bounded due preview without IDs or private content; synthetic negative tests.
- `OwnerOutboxHealthController#index`: only owner GET `/workspace/outbox/health`, no-store, not-found for guest/client/owner without workspace; no replay action; UI RU/EN/HY/ES and tests.
- `DomainOutbox::Replayer.run!(workspace:,limit:)`: low-level internal bounded 1..100, per-event row `with_lock`, atomic activity projection, stale failure handling, exponential retry, terminal attempt cap. No provider/AI billing, emails or canonical source writes. Existing synthetic tests validate idempotence, due/workspace, attempt bounds.

## First unimplemented feature gate

**C2.3b6b2.1 server-side supervised service boundary:** never accept arbitrary workspace ID. Require persisted authenticated owner and owner-owned workspace, check small allowlisted positive batch size; separate readonly preview from actual invoke. If a service is added, keep it private/unreachable via HTTP until operator audit, idempotency and concurrent safety are covered. Target tests: nil/client/foreign owner rejection; other tenant untouched; invalid/too-large limit; no provider/extra `AiSpendEntry`; no automatic invocation on GET.

**C2.3b6b2.2 owner POST action (later gated):** authenticated owner-only CSRF-protected POST, explicit scope+limit and human confirmation, display only aggregate counts; never replay on GET, never reveal event IDs, source names, token digests, client answers or prompts. Require stable duplicate-command key/cooldown, safe result after failure/timeout, and human UI role/viewport acceptance.

**C2.3b6c2 concurrency + durable actor audit (later gated):** no persistent per-run actor record exists. Design minimal, immutable, privacy-safe operator log (actor/workspace, requested limit, run id, timestamps and aggregate outcome), PG transaction and per-workspace lock/rate limits, worker parallel race test, idempotent duplicate POST, no second AI charge. Do not create audit events by faking canonical client/source `ActivityEvent`. New DB migration requires separately scoped local/production approval.

## Release sequence

Code + synthetic tests → exact SHA Rails/Chrome/PG18/Security → owner/browser role and viewport QA → separately authorized local review DB migration if needed → M8 staged release/rollback. Original source review DB, private archive, scratch, original `db/schema.rb M`, port :3001, Railway/main not to be touched without new permission. No real replay has been invoked.

## C2.3b6b2.1 implementation checkpoint — 22 Nov 2026

Code commit [`a3b4f83`](https://github.com/TheGor-365/rails_calendar/commit/a3b4f83a287983e6cc3de1a54d42d4f5d64aae1e) added `DomainOutbox::OperatorAccess` with fail-closed persisted owner/workspace authorization, explicit association owner ID comparison, and stricter allowlisted manual batch size 1/5/10/25. `DomainOutbox::Health.scoped_events` now shares this same gate; read-only HTTP remains GET-only. `test/services/domain_outbox/operator_access_test.rb` covers two owners/workspaces, nil/client/owner-no-workspace and invalid request limit, and asserts no changes to outbox, ActivityEvent or AiSpendEntry. Code/tests committed; full exact-SHA Rails CI pending at checkpoint; Security Audit SUCCESS. NO replay route or service writer or audit DB introduced. This completes only code preparation b6b2.1, not operator POST/actor audit/concurrency.
