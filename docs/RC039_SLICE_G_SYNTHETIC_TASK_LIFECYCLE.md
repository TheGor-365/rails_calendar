# RC-039 Slice G — synthetic task lifecycle, priorities and immutable audit

**Environment:** Rails test mode only, owner-only, explicitly fictional. No routes or production UI. This is not a workflow for customer obligations, client deliverables or real worker assignments.

## Schema and invariants

Additive migration \`20261112163000_add_studio_synthetic_task_lifecycle.rb\` extends the Slice F *synthetic task* table with \`state\` (default \`proposed\`), \`priority\` (1 highest through 5 lowest; default 3), and ActiveRecord \`lock_version\` (default 0). PostgreSQL checks restrict each field. Existing synthetic tasks retain their fixed catalog key and workspace/client/intake foreign keys; nine document-artifact cards remain a different model.

The new append-only \`studio_synthetic_project_task_events\` table records each successful owner action with tenant identity, task ID, actor, monotonically increasing version, before/after state and priority, event type and timestamp. Composite FK protects the task scope; check constraints reject unsupported transitions, priority changes on completed tasks, self-contradictory event types and invalid priorities. Unique \`task_id/sequence\` prevents duplicated event versions. ActiveRecord callbacks prevent supported update/delete of task identity and events; database administrative writes are **not** claimed to be unbypassable.

## State and dependency contracts

\`proposed → ready → in_progress\`, \`in_progress → blocked → in_progress\`, and \`in_progress → completed\`. \`completed\` is terminal. In this test-only prototype, every state is a **fictional simulation**; \`completed\` never represents accepted, invoiced or verified client work.

\`Studio::SyntheticProjectTaskLifecycle\` uses the existing active owner membership, exact scoped intake, explicit \`explicit_synthetic: true\`, \`Rails.env.test?\`, and \`!Rails.env.production?\`. Every transition or reprioritization takes the same \`ProjectIntake.with_lock\` lock as the Slice F task graph and checks an exact expected state/version, then writes the task and immutable event in one transaction. Unsupported edges, stale versions, missing prerequisites and revoked/foreign owner access fail without a receipt. PostgreSQL FKs/constraints provide additional tenant- and graph-level integrity.

- A task cannot enter \`ready\`, \`in_progress\`, or \`completed\` while any existing prerequisite is not \`completed\`.
- \`SyntheticProjectTaskGraph.add_dependency!\` refuses **new** edges after the dependent task leaves \`proposed\`; an existing edge remains idempotent. This avoids invalidating a prior readiness decision via the supported graph workflow.
- Priority changes must be 1–5, change the value and target a noncompleted task; they also check optimistic version and append an event.
- Independent eligible nodes in \`topological_task_keys\` are ordered by ascending priority then fixed task key, but prerequisite-first order always wins. No hours, durations, critical path, resource capacity or delivery dates are inferred.
- The original Slice F \`state: proposed_unverified\` receipt remains backward-compatible for a proposed task; new \`workflow_state\`, \`priority\` and \`version\` fields expose the simulation state explicitly. Every output keeps \`client_confirmed=false\`, \`approved=false\`, \`task_execution_authorized=false\` and no provider calls or spending.

## Acceptance and limits

Nine test scenarios exercise full lifecycle, blocked/resumed paths, missing prerequisites at ready and completion even after direct SQL injection of an edge, deterministic priority ordering, stale revision rejection, revoked/foreign owner access, immutable audit, SQL constraints and nonproduction gating. No existing client facts, document artifacts, project milestones or consultation-calendar rows should change.

Owner Linux Mint QA must check the isolated \`rails_calendar_rc039_qa\` status and **preserve its modified \`db/schema.rb\`**. Update the detached branch to the exact PR SHA; migrate **only** local \`ruby_calendar_test\` using the previously proven \`RAILS_ENV=test\` / \`RC_LOCAL_TEST_DATABASE_URL\` configuration. Then run targeted task lifecycle tests, all Rails tests and Chrome system tests, plus exact-head push/PR CI and Security Audit. Never run \`db:drop\`, \`db:reset\`, force-reset, schema checkout or merge/deploy as part of acceptance.

### Deliberately not built

No real project-task CRUD, freeform descriptions, assignments or permissions for staff/clients; no project-only calendar views, milestones duration calculations, synchronized consultation calendar, keyboard Kanban reorder, production routes, external AI, source imports, files, billing or tenant encryption pipeline. Future genuine task-management release requires human scope signoff, RBAC/identity/consent, file security, data protection, project-only calendar/critical path algorithm validated against accepted estimates, and E2E acceptance.
