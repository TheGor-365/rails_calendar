# RC-039 Slice B — synthetic-only card model and owner transition receipts

**Test-only, nonproduction, no client-visible UI.** Adds two small metadata tables and an owner-scoped service on top of RC-039 Slice A: \`Studio::SyntheticProjectCard\` and immutable \`Studio::SyntheticProjectCardTransition\`. This remains a synthetic backend exercise, not a released task management system.

Cards are scoped to \`workspace_id/client_id/project_intake_id\` using PostgreSQL composite foreign keys, carry a fixed \`artifact_key\` from the existing nine-card \`Studio::DocumentGenerationPlan\`, an owner ID and one of three *nonapproval* states: \`backlog\`, \`in_review\`, \`on_hold\`. There is **no** title, description, PII, source content, due date, assignment, client collaboration or approved/completed state. One card per intake/artifact; repeated creation returns the existing card.

\`Studio::SyntheticProjectCardWorkflow\` verifies exact active owner permissions, project scope, \`Rails.env.test?\`, explicit opt-in, and \`!Rails.env.production?\` for every operation. All transitions are serialized under a row lock and require an expected state plus optimistic \`lock_version\`; stale mutations are rejected. Allowed edges are \`backlog→in_review\`, \`in_review→on_hold/backlog\`, \`on_hold→in_review/backlog\`. The card update and its append-only audit receipt use one database transaction; failed logging rolls back the card transition. Model callbacks reject direct state updates and log edits/deletes, while database checks reject approved status, unsupported transitions and cross-tenant rows. The display receipt never authorizes documents or client acceptance.

No controllers, Turbo Streams, routes, real tasks, calendar synchronization, grants, AI, exports, cloud files or payments. Model-level checks and a test-only service are a **prototype safety envelope**, not a substitute for a full role policy, key management, auditing and malicious SQL write protections before public availability. Tests use only \`ruby_calendar_test\` and fictional actor/client/project identities.

### Acceptance

- Verify migrations in *an isolated disposable local test database only*: no \`db:drop\`, \`db:reset\`, production URL or write to the user's development database.
- Run \`test/services/studio/synthetic_project_card_workflow_test.rb\`, then full Rails tests, exact-head GitHub CI and Security Audit.
- Confirm DB check constraints and tenant foreign keys are effective. A generated \`db/schema.rb\` stays uncommitted in the dedicated QA worktree until reviewed.
- RC-039's functional Project Hub UI, owner-restricted HTTP mutation routes, keyboard drag/drop, real client identity/consent, production encryption/AV, backup/restore and release signoff are separate pending stages.
