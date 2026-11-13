# Client ↔ Owner Product Pilot — local synthetic-only

2026-11-13. Draft PR stacked on i18n PR48, not on main, not deployed.
Base: PR48 SHA 7b17dae25228d9a4241685f95e6d807790f20984.

## Existing features reused, not reimplemented
Owner login/Workspace, client OTP registration, four-language UI, consultation calendar,
owner synthetic Intake, offline Quiz, interview, template or gated Grok draft,
human revised/approved immutable spec versions and proposed milestones.

## Implemented minimal two-account bridge
- Nullable `project_intakes.client_user_id`, indexed FK to users, old synthetic rows untouched.
- Local-only flag `RC_LOCAL_CLIENT_REQUESTS_ENABLED=true` on loopback development.
- Client verified DB account creates fictional test request; server assigns client_user_id
  (never from params). Stores a client initial message and a template response.
- Owner sees request in existing inbox, can review, draft and approve via existing flows.
- Client home queries ONLY the logged-in verified user's requests. The client's
  scoped request detail shows only the latest **owner-approved** specification,
  and proposed milestones attached to that approved revision.
- Client may record reading one approved version; this is NOT scope/price/date
  acceptance, and owner stays responsible. Cross-client IDs yield 404.
- Owner-only Quiz and legacy Intake controllers are intentionally unchanged.
- Four languages en/ru/hy/es. No generated JS changes.
- No live Grok, paid API, AI-generated actions, real SMTP, real customer data, production flags or
  scope change. Approval remains owner-only.

## Manual local activation only after exact CI
Existing localhost:3012 preview with Ruby 3.4.12 and DB `rails_calendar_mvp_preview_20261112`.
Do not touch localhost:3015 old environment or QA worktree.
Check code HEAD and build; verify DB identity and apply ONLY
`ruby bin/rc-preview-client-requests-migrate` to preview DB after user approves
that additive local migration. Requires RAILS_ENV=development, DATABASE_URL unset,
RC_LOCAL_DEV_DATABASE_URL host loopback port5432 db name exact; refuses repeat.
No migration on production. Launch :3012 with RC_CLIENT_SIGNUP_ENABLED=true,
RC_LOCAL_CLIENT_REQUESTS_ENABLED=true and RC_GROK_ENABLED=false.
First verify second client OTP in incognito via dev mailbox file
`tmp/signup_emails`; do not share password/code.
Owner regular session remains intact. Use only fictional client project details.

## Next product slices
1. Replace owner-only two-step quiz with client-scoped adaptive A–H path
   with immutable Answer revisions and account/tenant-scoped ACL.
2. Bidirectional typed clarification/messages, owner notification via verified
   transport, explicit spec acceptance/change request on exact revision,
   project tasks and progress events under approved scope.
3. Grok isolated owner-only synthetic pilot using independent PR41 mock
   contract, strict JSON schema, server-side key, provider-cost reservation,
   durable integer-ticks ledger, idempotency, 429/timeout fallback and privacy.
   Never simply set RC_GROK_ENABLED=true: legacy Intake::Grok has only a
   daily call limit, not real USD budget accounting.
4. Backup/restore, staging migration/rollback, tenant privacy, verified SMTP
   and real customer workflow needed before production rollout.
