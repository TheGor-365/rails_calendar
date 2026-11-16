# RC055.1f C2.1a — owner-only durable conversation storage

**Date:** 2026-11-17. **Parent:** Draft PR #76 `bffe02fd7b0f9126cf671bdd0a114984df5ea13c`. **Status:** isolated proposed migration/models + tests; actual user preview migration NOT run, no client/AI endpoint.

## Recovery gate evidence: PASS (owner terminal)
- Owner clean local branch #76 `bffe02f` verified direct PG16.11 clients, stopped local Rails/Puma on 3012 and background processors, explicitly ran `RC_CONFIRM_WRITERS_STOPPED=YES RC_CONFIRM_ISOLATED_RESTORE=YES bash script/rc0551f_c21_backup_and_verify.sh`.
- New private PostgreSQL custom archive verified with SHA256. A separate new scratch database was created and restored. All NINE critical table row counts matched source.
- Entire local `storage/` archived, checksum validated, extracted into a private separate directory; `diff -qr` confirmed contents matched. Source preview database and storage unchanged. Backup archive and scratch database PRESERVED; do not remove, publish or overwrite.
- Important scope: does NOT independently verify application-level decryptability or restore encryption/master keys; owner should preserve the required secrets separately. C2.1a can now be **developed/tested**. Production and user-local preview migration still separately gated.

## This PR: data layer only
- `OwnerAiConversation`: belongs to `Workspace` (owner role only); title <=100, `state=active|archived`, scope `owner_general`, optimistic `lock_version`, explicit `retention_expires_at` required, timestamps and indexes. No owner ID copied unnecessarily. Removal is blocked until an explicit retention policy.
- `OwnerAiMessage`: belongs to one conversation; `role=owner|assistant`, status, max 1200 owner chars/2800 assistant chars, UUID `request_id`, monotonically allocated `sequence`, optional same-conversation parent ID, optional same-owner settled `AiSpendEntry`, operation allowlist, profile version, timestamps. Message body/edit/delete is blocked after insertion in this initial slice; future status reconciliation requires an audited design. Per-conversation unique request ID and sequence indexes; composite self-FK forbids parent links into foreign workspaces even via unsafe raw SQL; DB check constraints enforce role/state/body limits and forbid settled assistant output without a ledger FK.
- `OwnerAiConversation#append_owner_message!` serializes appends under row lock and returns the existing message if the SAME UUID and normalized text are retried, raising a conflict if another body reuses the UUID. Archived or expired conversations cannot accept messages. This is currently an internal model method invoked ONLY by synthetic tests, not from a web form, external API, Grok or client.
- `OwnerAi::ConversationAccess.for_user` returns only the signed-in user's owner-workspace relation; clients, guests, foreign owners receive empty or scoped relations. This is an authorization helper, not by itself permission for arbitrary owner messages.

## Explicitly excluded
- NO new Rails routes, controllers, forms, recurring jobs, user-visible conversations, client chat, documents, auto-ingestion, model calls, billing, calendar actions, publication or contract signatures.
- NO automatic provider context from the stored transcript. C2.1c will require per-turn consent, bounded context, cost reservation and fail-closed uncertain billing.
- NO retention deletion/TTL job or final user-facing retention policy; storing real user prompts through a controller is BLOCKED until the policy, disclosure, export and controlled deletion semantics are explicitly reviewed.
- DO NOT alter the user's preview PostgreSQL or Active Storage with automated integrations. CI test DB is isolated PostgreSQL 15, app runtime preview PostgreSQL 16.11.

## Schema mismatch caution
- Owner's real preview database has 10 `active_storage_blobs` and `active_storage_attachments` records; canonical `db/schema.rb` currently does not include these tables, even though they were included in the verified full PG custom dump.
- This PR introduces a migration only. Do **not** hand-edit or overwrite `db/schema.rb` with a schema regenerated from an unrelated empty CI database: it could omit the existing live Active Storage layout.
- After Rails CI, execute the migration first on the separately restored local scratch DB (never production) with an intentionally configured database URL. Inspect regenerated schema and compare all production-independent tables, FKs, checks and private media references. Reconcile Active Storage with the real source before committing the regenerated canonical schema. Do NOT run `db:schema:load`, `db:reset`, `db:drop`, or restore over preview.

## Acceptance criteria
1. Exact-HEAD Rails CI all controller/model tests and Chrome UI PASS, Security Audit 3/3.
2. Synthetic model tests cover owner/foreign/client scope, UUID idempotency, ordering, archiving/expiry, immutable message history, parent foreign scope and foreign AI ledger denial. No real network AI call.
3. Inspect all migration/version DB constraints on *isolated scratch DB*, agree explicit transcript retention policy and privacy notice before exposing any write route.
4. Only then C2.1b private White Atlas conversation UI; C2.1c per-turn paid provider gateway; C2.2 typed actions and review/apply.
5. Keep stacked PRs Draft and unmerged; no Railway deploy until explicit owner acceptance, backup/restore of production env and full ancestor release plan.

## Remaining visual QA
Mobile 390/320 real-browser screenshot of floating AI panel and possible text overlap P2; previous desktop White Atlas screenshots provisionally accepted.
