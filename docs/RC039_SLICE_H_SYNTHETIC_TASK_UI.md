# RC-039 Slice H — engineering-task forms in synthetic owner Project Hub

**Scope:** a narrow, test-only UI integration of *existing* F–G services. No new schema, no external AI, no client data, no actual task commitments, no production routes.

## Alignment with AI Service Workspace master plan (08.11.2026)

The product's objective is **qualified leads → verified requirements/spec revision → approved scope → real project workspace → verified deliverables**. Its three zones are the public Smart Intake Quiz, client cabinet, and developer workspace. Consultation booking and the development project calendar must remain distinct. The master plan defines RC-039 acceptance as a **working client cabinet**, not a static board.

Slices A–G already verified a nine-card *document preview* and a separate six-node *fictional engineering task DAG*, with an owner-only lifecycle and append-only audit. Slice H links that existing task graph to the test-only owner page. It **does not satisfy the product-level RC-039 client-cabinet gate**.

## Exact Slice H changes

- Existing \`GET /workspaces/:workspace_id/clients/:client_id/project_intakes/:project_intake_id/project_hub/preview\` renders the unchanged nine-document board **and** a separate six-step fictional engineering-task panel (no client names, scope, real source text or unapproved estimates).
- Fixed-key \`Create fictional task\`, \`Change task state\`, \`Change task priority\` and \`Add prerequisite\` use four new HTML routes nested **only in \`if Rails.env.test?\`**, plus controller runtime hard-deny and active owner/tenant/client/intake guards. The original JSON contract is unchanged.
- Mutations delegate exclusively to \`Studio::SyntheticProjectTaskGraph\` and \`Studio::SyntheticProjectTaskLifecycle\`. Only six predefined task keys and legal versioned state/priority changes are possible. Cross-project, stale, cyclic and uncompleted-prerequisite updates are refused; task and event stay atomic. Untrusted payload fields (client/approval/task body/dates) are ignored.
- 409 conflict and 422 invalid action rerender the *current scoped* task board with an accessible alert and reload link rather than performing an automatic retry. A successful action returns a POST/redirect/GET anchored to the task panel. Existing document-only actions remain unaffected.
- Priority (1–5), version, current state and prerequisite status are shown. Tasks cannot be promoted with incomplete prerequisites in the UI, while the service independently enforces the rule. Dependency order always beats priority.
- Responsive White Atlas CSS: 3 columns desktop, 2 tablet, 1 narrow mobile, full-width keyboard-operable native forms, no drag-and-drop, no new JS/Stimulus feature.

## Test evidence required

- HTTP integration \`test/controllers/studio/synthetic_project_hub_tasks_ui_http_test.rb\`: owner and guest/foreign/revoked ACL, nine documents remain unchanged, fixed task creation/idempotence, optimistic version, priorities, dependency denial/cycle, no private-text reflection, no calendar or milestone mutations, CSRF and production/non-test denial.
- Chrome \`test/system/studio_project_hub_browser_test.rb\` adds a 320/390/430px task flow: create → ready → reprioritize, no horizontal overflow. Prior Chrome tasks continue unchanged.
- Exact-head push/PR Rails CI and Security Audit, then isolated owner Linux Mint targeted/full Rails+Chrome acceptance.

### Local QA

Use existing detached \`rails_calendar_rc039_qa\`; do not reset/stash/commit its **modified** \`db/schema.rb\`. No Slice H migration. Run with \`RAILS_ENV=test\`, \`RC_STUDIO_QUARANTINE_BACKEND=disk\`, \`PGHOST=127.0.0.1\`, \`RC_LOCAL_TEST_DATABASE_URL=postgresql://postgres@127.0.0.1:5432/ruby_calendar_test\`, and unset unrelated \`DATABASE_URL\` / \`RACK_ENV\`.

### Product-level RC-039 gates still open

1. Explicit accepted requirement/spec revision linked to a **real** \`Project\` with verified owner and client grants. Never auto-create from unapproved AI text.
2. Real task/role/assignment model and per-client RBAC matrix, verified account identities, comments, progress events, audited human review and acceptance. The synthetic \`completed\` status is not client acceptance.
3. Project timeline and calendar independent of consultation bookings, confirmed working-day/duration estimates and auditable critical path; no fabricated due dates.
4. CSRF/XSS/IDOR/security E2E, consent/retention and upload scanning, backup/restore verification and manual assistive-technology review.
5. Only then a gated client cabinet release and production-readiness decision; RC-040 export and RC-041 commercial inbox remain separate milestones.

No merge, production deployment or Railway data modification as part of Slice H. This continues the user-selected master plan without misrepresenting a synthetic preview as an end-to-end client workflow.
