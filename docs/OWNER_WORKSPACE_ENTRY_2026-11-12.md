# Owner workspace — safe release slice (2026-11-12)

Branch `feat/owner-workspace-entry-2026-11-12` / Draft PR #43, layered on Draft PR #42, itself on MVP-A #40. Not deployed.

## Product map

- Guest /: production route renders public /services, with 4 categories and external Facebook / Kwork contact. No guest writes or public client data.
- Owner /workspace: **real authenticated route** after owner login; three read-only DB counters, 4 actionable navigation cards and recent consultations + legacy synthetic request summaries.
- Future client: *not registered* in RC-035-based release cut. RC-036+ tenant-membership code is in separate Draft line, not safely shipped. Do not reuse the owner-only global DB queries for clients.
- AI: not called by this dashboard; no xAI API key required, Grok pilot remains separate offline contract.

## Navigation

Owner login and local first-owner signup redirect to /workspace; the existing Calendar stays at / to preserve links. New owner brand link returns to /workspace; legacy admin cookie does not grant /workspace access. Existing consultation CRUD and intake permissions are unchanged. No new migrations.

## Development preview

Local user's separate worktree is at `~/rails_calendar_mvp_release_20261112`; their RC-039 QA worktree includes a modified schema file and must not be changed.

The screenshot established that /services loads. Later a new terminal/session showed `RC_LOCAL_DEV_DATABASE_URL` unset and Ruby 3.4.7 even though this repo requires 3.4.12; these are local environment issues, not a production defect. Build `yarn build && yarn build:css` succeeded on 3.4.12 code.

The separately-created local DB `rails_calendar_mvp_preview_20261112` exists, but `db:schema:load` failed because inactive test environment config omitted its adapter. **Never rerun general `db:prepare` or `db:schema:load` against a DB without verifying its identity.**

`bin/rc-preview-schema` is an explicit, opt-in schema loader with five safeguards: requires development, no production DATABASE_URL, loopback postgres URL exactly preview DB name, actual `SELECT current_database()` match, zero relations in all non-system schemas. It refuses populated DBs; `load db/schema.rb` may create/drop schema objects only after all checks pass. Never run against shared QA/test/prod DB. It does not attempt automatic migration or backup. Do not store or paste DB URL or password in GitHub/chat.

## Release gates

- Exact SHA GitHub CI + Security Audit.
- Local owner login /workspace GET, route links, old calendar CRUD and guest denial, 320/390/430 desktop/mobile, no horizontal overflow.
- Real external message delivery checked by owner.
- Railway preDeploy db:migrate risk, backups + isolated restore, rollback, explicit GO before deployment.
