# Client email signup — staged, not released
2026-11-12. Draft based on owner Workspace PR #43; separate migration, not MVP-A code-only.

## Intent
Public customer accounts with one-time email verification. No existing `/sign_up` owner bootstrap replaced. Identity is distinct from membership. This is not an accessible project board, real client submission, or Grok release.

## Implemented contracts
- Explicit `RC_CLIENT_SIGNUP_ENABLED=true` required in any environment; production also requires `RC_SIGNUP_LEGAL_APPROVED=true` and all of `RC_SIGNUP_FROM`, `RC_SMTP_ADDRESS`, `RC_SMTP_USERNAME`, `RC_SMTP_PASSWORD`.
- Production mailer uses TLS-capable SMTP from protected variables; no default SMTP credentials. Development writes messages into gitignored `tmp/signup_emails/` as FILES and never sends external email. Tests use `:test`.
- `GET /register` and `POST /register` create only `ClientSignupChallenge` with bcrypt password digest. No `User` before a correct code.
- Random 6-digit code, HMAC-SHA256 digest at rest, 10-minute expiry, maximum 5 incorrect attempts, one-time use enforced under PostgreSQL row lock and unique email constraint. Resend cooldown 60 seconds, maximum 3 sends/hour, resets after hour. Per-IP and per-email rate limits are shared PostgreSQL counters (HMAC identities; no raw IP stored). Form/URL never contains a code. CSRF required outside tests.
- Verified account has role `client`, `email_verified_at`, `signup_consent_at`, revocable DB-backed session, and `GET /client` containing no owner or client project data. No access to owner `/workspace`, private consultations, demo-intake admin, or global owner DB queries.
- Existing owner login/registration and legacy admin sessions remain distinct.
- Authentication form supports either owner or a verified client account; signup does not grant owner or workspace membership.
- New migration adds 2 columns to `users` and two new tables; it is **not applied to production**. `db/schema.rb` checked in for isolated preview.
- Manual cleanup task `bin/rails client_signup:prune` is provided; a monitored schedule must be configured before live traffic.

## Non-negotiable production GO gates
1. Formal privacy/terms version approved by operator and compatible with actual retention/deletion process. Current `/register/privacy` is a technical notice for QA, **not approved legal policy**.
2. Verified SMTP sender/domain (SPF/DKIM/DMARC as applicable), observed real email delivery to external test mailboxes, bounce/rate/cost handling and sender reputation. A successful `deliver_now` is not proof of inbox delivery.
3. Password recovery, account deletion/export, support contact, anti-abuse and monitoring. Current password-reset flow is NOT built, so public release remains NO-GO.
4. Separate database backup and isolated restore, migration up/down verified on a staging clone, rollback strategy for `db:migrate` and deployment service verified.
5. Exact-HEAD Rails/Chrome/security CI, local browser responsive QA, registration expiration/replay/resend/locked/account collision stress, and real client ACL/tenant isolation before accepting project data.
6. No public real-client Intake/AI/file uploads or human claims until their own E2E/consent gates pass.

## Local QA
Use only `~/rails_calendar_mvp_release_20261112` with verified local `RC_LOCAL_DEV_DATABASE_URL` ending in `/rails_calendar_mvp_preview_20261112`; the preview schema was created earlier on local 127.0.0.1:5432. Do NOT run `db:reset`, `db:prepare` or `db:schema:load` on shared QA DBs or Railway. This branch's migration must be applied only to isolated preview, after explicit identity check and a migration-diff review. Owner QA worktree RC-039 must remain unmodified.

To enable local test of the form on a fresh server process, export `RC_CLIENT_SIGNUP_ENABLED=true`; Ruby 3.4.12 is required. Local verification codes are stored in `tmp/signup_emails`; treat them as secrets and do not paste/send screenshots of them.

### Auditable privacy version

A client and its pending challenge now record a policy version together with consent timestamp. Production registration additionally requires protected `RC_SIGNUP_POLICY_VERSION` and an approved absolute HTTPS `RC_SIGNUP_PRIVACY_URL`; the public form links to the reviewed version. Development uses explicit `qa-2026-11-12`, not a legally approved document. Env flag alone cannot bypass these requirements.
