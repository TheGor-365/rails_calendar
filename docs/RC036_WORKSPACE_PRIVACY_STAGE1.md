# RC-036 Stage 1 — workspace-scoped client memory, privacy foundation

Date: 2026-11-10. Stacked on RC-035B Draft PR #35, exact parent
\`375335e96e51ebff2a4eaf4fbf484125ce4cd26a\`. This branch is
**not production ready**. No client onboarding, no AI provider, no public
intake, no attachment access, no payment or notification actions.

## Motivation

The current owner-only \`Intake::Intelligence::ContextAssembler\` works with
one \`ProjectIntake\`. It does not provide cross-project customer memory or
tenant-level ACL. The next foundation introduces explicit ownership and
append-only customer facts without inventing customer identities or mixing
unrelated briefs.

## Data model (additive migration, staged only)

- \`Workspace\`: named workspace with a persisted owner and internal/suspended
  state. An owner also requires active \`WorkspaceMembership\`.
- \`WorkspaceMembership\`: explicit role/status; this stage **authorizes only
  the owner role**. Future client/developer access is not wired to routes.
- \`Client\`: minimal synthetic label and workspace scope, no email, identity,
  KYC or external contact data at this stage.
- \`ClientFact\`: immutable revision with field key, bounded JSON, fact
  status (reported/verified/suggested/disputed/unknown/excluded), source,
  sensitivity, purpose, recorder and expiry.
- \`ClientConsent\`: append-only grant/revoke events per purpose including
  future external_ai. No implied consent and no automatic provider activation.
- Composite foreign keys \`(client_id, workspace_id)\` enforce tenant consistency
  in PostgreSQL, not just in Rails validation.
- No backfill or reassignment of existing \`ProjectIntake\`, consultations,
  specifications, attachments or historical data. The relationship between
  existing intake and real customers remains **unassigned**.

## Internal services

\`WorkspaceMemory::Access\` fail-closes without active owner membership and
matching workspace/client. \`WorkspaceMemory::Repository\` offers:

- \`record_fact!\`: serializes revision allocation with the client row lock;
- \`current_facts\`: takes the newest revision first; excludes latest
  disputed/excluded/expired values rather than resurrecting old facts;
- \`history\`: one client's exact ordered fact revisions;
- \`record_consent!\` / \`consent_state\`: explicit opt-in/revocation history;
- \`provider_payload\`: always raises \`SecurityError\` pending RC-036/037.

All service reads are scoped by both actor and workspace/client.
Models reject normal updates/destroys of fact and consent records. This is
an application-level append-only contract, **not yet** a database trigger:
direct SQL/table permissions and retention policies require security review.

## Do not confuse safe foundation with privacy completion

- \`ClientFact.payload\` is raw PostgreSQL JSONB, not application-encrypted.
  **Do not store real client PII or sensitive data before encryption, explicit
  consent, retention/deletion design and complete workspace ACL review.**
- No externally reachable routes or account changes. \`User.role\` remains
  owner only; no invitations, password reset, per-client dashboards or client
  authentication yet.
- All fake customer examples in tests are synthetic.
- No cross-client retrieval, AI embeddings, RAG, provider calls or spending.
- Owner's private internal memory is not a license to export a customer's data.
- Expiry currently filters reads; physical deletion and legal retention
  still need dedicated engineering.

## Remaining RC-036 gates

1. Verify model/migration tests in isolated CI and do a schema review.
2. Add workspace ownership to new client-bound \`ProjectIntake\` with
   controlled ownership backfill strategy for synthetic legacy records.
3. Implement policy-based \`WorkspaceScope\` for every path, background job,
   Turbo Stream, search/export and private file delivery.
4. Invitation/identity verification/session revocation, explicit privacy and
   consent flows, encryption for sensitive fields, retention/delete policies.
5. Prove client A cannot access any data of client B, even in direct URLs,
   attachments, exports, search or AI retrieval. Only then enable client
   sign-up and submit.
6. Reconcile RC-035B owner-only release gate, including proven Postgres
   backup/restore, before any production migration.

## Acceptance

Exact SHA CI/Security PASS; denied cross-tenant reads and writes; a revoked
membership blocks access; consent revocation wins; facts have immutable
version history; provider integration remains prohibited. No production
changes or customer records.
