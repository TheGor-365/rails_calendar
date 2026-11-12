# RC-039 Slice I1 — evidence-bound Project foundation (test-only)

## Product alignment

The 08.11.2026 AI Service Workspace master plan requires **approved requirements → a scoped Project → real task/progress management → client cabinet**, while keeping the consultation calendar separate. RC-039 exit criterion is a **working client cabinet**; Slice I1 is only the first domain/admission gate. It does not satisfy that exit criterion or grant real client tasks.

Slices A–H: nine synthetic document cards and six fictional engineering tasks. Those do **not** become real Project or Task rows. This slice creates two distinct, additive tables with no new routes or modified consultation/calendar records.

## Evidence and admission policy

1. \`IntakeSpecVersion.owner_approved_at\` is evidence of **owner** approval only. \`client_reviewed_at\`, a mailbox verification, or the existing reviewer-only \`Studio::ClientProjectGrant\` **does not mean** the client has accepted a specification. The old admin approval endpoint is legacy-only and cannot approve a new workspace intake by itself.
2. \`Studio::ProjectScopeAcceptance\` captures a proposed explicit client-side acceptance of the **exact latest owner-approved spec revision** by a particular \`Studio::ClientAccount\` using an active client/project-specific reviewer grant and its previously verified invitation. It requires the client's *presented* canonical SHA-256 content fingerprint and a separate explicit confirmation flag. Every field is tenant-linked through composite PostgreSQL foreign keys; raw spec text and personal identifiers are not copied into the receipt.
3. The underlying service \`Studio::ProjectScopeAdmission.accept_spec!\` currently has **no HTTP route**, and receives an \`actor\` object as an argument. In a future client acceptance endpoint, the actor must be obtained exclusively from a validated server-side client session; do not take a client ID, grant ID or \`explicit_confirmation\` from an owner impersonation or arbitrary URL. Current acceptance records are **test fixtures**, not evidence that a real person approved an actual contract.
4. \`Studio::ProjectScopeAdmission.activate_project!\` requires the active workspace owner, same workspace/client/intake, a still-active client grant, the exact acceptance receipt and the latest owner-approved version with an **unchanged** SHA-256 document. Any later draft/revision or content mutation blocks activation rather than silently substituting a version.
5. \`Studio::Project\` is created in immutable status \`internal_scope_locked\`: **no task execution, project-calendar publication, billing, generated deliverables, or client portal access**. Only metadata-only owner/client summary methods exist, both requiring renewed access checks and explicit test-mode admission.

The canonical content hash sorts object keys recursively but preserves array ordering. It is content-integrity evidence, **not** a cryptographic client signature, authentication credential, or substitute for consent, KYC, a commercial agreement or a correct document signing process.

## Database and security

Additive migration \`20261112190000_create_studio_project_scope_foundation.rb\` introduces \`studio_project_scope_acceptances\` and \`studio_projects\`, with:
- Composite FKs to the *same* intake, client, workspace, spec revision and accepting client grant/account, and an exact composite reference from project to acceptance including document digest.
- Unique one acceptance and one internal project per intake, to refuse a second or conflicting revision until a separately reviewed change-order protocol exists.
- SHA-256 format checks and immutable record callbacks; SQL administrative access is not equivalent to application-level security.
- No raw documents, source contents, human-readable project descriptions, passwords, email addresses, signed file bytes or PII in either table.

All service admission is hard-denied unless \`Rails.env.test?\`, \`!Rails.env.production?\`, \`explicit_synthetic: true\` and an internal workspace. No new production or development routes.

## Acceptance

New test service suite \`test/services/studio/project_scope_admission_test.rb\` covers successful internal metadata-only scope lock, owner approval not equal to client acceptance, exact hash and revision, stale/tampered scope, foreign tenant/account, revocation/suspension, immutable records, composite SQL FKs and nonproduction refusal.

Owner's isolated \`rails_calendar_rc039_qa\` must:
- Fast-forward to exact Slice I1 HEAD, preserving its existing modified/uncommitted \`db/schema.rb\`;
- migrate **only** PostgreSQL \`ruby_calendar_test\` with \`RAILS_ENV=test\`, unset \`DATABASE_URL\`/\`RACK_ENV\`, \`PGHOST=127.0.0.1\` and \`RC_LOCAL_TEST_DATABASE_URL=postgresql://postgres@127.0.0.1:5432/ruby_calendar_test\`;
- run new targeted service tests, full Rails test suite and full Chrome system suite;
- confirm four exact-head GitHub CI/Security checks. No merge/deploy.

## Still necessary for RC-039 (not silently done)

**I2:** project-specific authorization matrix and Task/ProgressEvent model using actual verifiable identity and assignment, not synthetic card statuses. **I3:** client/owner HTTP routes with secure sessions, read/write boundaries, explicit spec review+accept flow, revocation and E2E IDOR/CSRF tests. **I4:** separate project calendar, authenticated comments/revisions and client deliverable review. **Exit:** end-to-end working client cabinet plus manual accessibility, security/privacy, backup/restore and separate deployment approval.

No Railway, production, real client identity or paid AI is touched by Slice I1.
