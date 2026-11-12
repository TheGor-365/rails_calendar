# RC-039 Slice F — isolated synthetic engineering task DAG

**Status:** test-only domain foundation, **not** live/project-client task management.

## Why a separate task model?

Slices A–E store nine prospective *document artifact* cards and their owner-only synthetic review states. They are **not** software development tickets, approved epics, accepted client work, production assignments or project milestones. RC-039 Slice F introduces a separate proposed engineering-task graph, without mutating that artifact catalog, the independent consultation calendar or earlier milestone proposals.

The fixed, text-free task catalog contains:

1. \`scope_review\` (discovery)
2. \`solution_design\` (definition)
3. \`rails_implementation\` (implementation)
4. \`interface_implementation\` (implementation)
5. \`quality_verification\` (verification)
6. \`handoff_preparation\` (handoff)

This is a **schema/algorithm verification catalog**. Actual task descriptions, assignees, comments, due dates, estimates, priorities, real milestones, completion and client authorization are deliberately absent. There is no extrapolation from existing document review receipts or AI proposals.

## Storage, integrity and authorization

Additive migration \`20261112150000_create_studio_synthetic_project_tasks.rb\` introduces:
- \`studio_synthetic_project_tasks\`: exact workspace/client/project intake, creator owner, catalog task key; one row per task key in each intake. Database check constraint restricts task keys; composite foreign keys prove client and intake belong to the same workspace.
- \`studio_synthetic_project_task_dependencies\`: an edge from a dependent task to one prerequisite task, with the same tenant identifiers and original owner. Database composite foreign keys on **both** endpoints refuse cross-project or cross-client edges; no self-links; unique edges.

Models are immutable through supported ActiveRecord callbacks. All **supported writes** pass through \`Studio::SyntheticProjectTaskGraph\`, which requires an active workspace owner and membership, explicit \`explicit_synthetic: true\`, Rails test environment and nonproduction. It serializes task and edge creation under a project-intake row lock; detects graph cycles before insertion; duplicate task/edge calls return the existing synthetic receipt. Snapshot returns a stable topological order with a deterministic key tie-break. Model-level owner validation and DB tenant FKs provide defense in depth; the service is **not** an unbypassable DB security policy for users with privileged SQL access.

No HTTP routes or owner UI are added by this slice. No real client uploads, personal data, calendar events, provider tokens, AI calls, dollars, task approvals or execution. Output explicitly marks \`critical_path_verified=false\`, \`client_confirmed=false\`, \`task_execution_authorized=false\`, and contains no claimed schedule or delivery date.

## Acceptance runbook

1. Verify \`git status -sb\` in isolated \`rails_calendar_rc039_qa\`. Existing local \`db/schema.rb\` is modified from earlier test-only migrations: **preserve it without reset, stash, checkout or commit**.
2. Fast-forward the detached QA HEAD to the exact commit from Draft PR #39 and run \`bin/rails db:migrate\` only with \`RAILS_ENV=test\` and \`RC_LOCAL_TEST_DATABASE_URL=postgresql://postgres@127.0.0.1:5432/ruby_calendar_test\`. Do not use the production/development DB, \`db:drop\`, \`db:reset\` or \`db:prepare\` with an unknown target.
3. Run \`bin/rails test test/services/studio/synthetic_project_task_graph_test.rb\`, then the full Rails suite, followed by the independent system suite on the same exact HEAD, with isolated test DB variables.
4. Check four exact-head GitHub push/PR CI and Security Audit results. These plus owner local tests constitute **automated synthetic acceptance only**.

### Open production gates

Separate approval is required for any real-world task capture or identity/roles: tenant-owned permissions, verified client and staff identities, consent and privacy classification, encryption/key lifecycle, trustworthy AV for files, audited task transitions, assignment authorization, backup-restore evidence, security E2E and explicit human release approval. A genuine project roadmap/critical path must be computed only after its durations and dependencies are reviewed. Future RC-039 slices can add real task state machinery and HTTP UI with this review; this slice makes no production-readiness claim.
