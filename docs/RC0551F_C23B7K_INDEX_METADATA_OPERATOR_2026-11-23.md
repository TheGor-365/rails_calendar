# C2.3b7k — invitation index metadata-only triage operator

**Date:** 2026-11-23; existing Draft PR #81. **Code submitted, exact-SHA CI pending; no new owner PG16 query authorized or executed. G5 remains BLOCKED.**

## Evidence and scope

The one previously approved C2.3b7j index catalog observation was consumed. It reported only a missing *valid+ready, non-unique* \`index_client_request_invitations_on_workspace_id_and_created_at\`. The migration \`20261119000500_create_client_request_invitations.rb\` and tracked schema prescribe the index, but C2.3b7j filters invalid/unready indexes. The cause on the historical scratch DB is unknown; do not infer corruption.

This change introduces:
- \`lib/domain_outbox/invitation_index_metadata_triage.rb\`: pure classifier and a fixed **one SELECT** querying \`pg_catalog\` on **only** \`public.client_request_invitations\` indexes and connection metadata. It checks exact name, valid/ready/unique flags, ordered key columns, access method, INCLUDE count, expression/predicate presence, table kind and fixed DB/socket/PG16/role/read-only identity. No application table rows, invitation tokens, PII or source rows.
- \`script/rc0551f_c23b7k_invitation_index_readonly.rb\`: manual-only guarded noninteractive PostgreSQL 16 Unix-socket operator, requiring **new consent**, exact isolated scratch, clean pinned SHA, OS role, cleared connection variables, read-only transaction default and strict timeouts. Raw metadata and libpq stderr are never printed.
- \`test/lib/domain_outbox/invitation_index_metadata_triage_test.rb\`: disposable CI PostgreSQL schema test, synthetic identity tests and wrapper denial tests, never connecting to owner scratch.

Bounded outputs: \`EXACT_EXPECTED_INDEX_PRESENT\`, \`INDEX_ABSENT\`, \`INDEX_INVALID_OR_NOT_READY\`, \`INDEX_NAME_OR_DEFINITION_DRIFT\`, \`INDEX_UNEXPECTEDLY_UNIQUE\`, or \`UNKNOWN\`. Even an exact index observation does **NOT** clear the previous 17-table G5 failure or independently prove a restored DB's consistency; operator always reports \`G5=BLOCKED\`.

## New independent permission is mandatory

**Do not invoke the operator until exact-SHA CI and Security Audit pass, a fresh clean worktree is independently pinned to the reviewed SHA and the owner explicitly permits exactly ONE new catalog-only read on the named existing PostgreSQL 16 scratch.** The previous C2.3b7j permission does not cover this operation.

Later provide one protected Linux Mint command with the verified commit SHA and new \`RC_APPROVE_C23B7K_INDEX_READ=YES_ONE_C23B7K_INDEX_CATALOG_READ\`, \`RC_REVIEWED_SCRATCH_NAME\`, and cleared inherited PG/DB connection variables. No interactive prompt, no raw output, no automatic retry. Until then, **no SQL commands to owner**.

Forbidden: source/review DB, business table-row scans, DDL/DML, migration, index repair, new backup/archive access, replay/writer, CI accessing private data, Railway or paid AI. Any later corrective action needs separate independent backup/restore proof and owner authorization.

## Current release ledger

Pre-change HEAD \`f665215ff30af47fd3f60371ff1a4980cfa4313c\`: Rails CI #45075893071 SUCCESS, Security #45075893120 SUCCESS, PG18 fresh/upgrade SUCCESS. New code commit SHA and corresponding workflow results must be recorded **after** independently checking GitHub. C2.2 QA, G3/G4/G6 backup/media/source/tenant gates, production and main merge remain OPEN.
