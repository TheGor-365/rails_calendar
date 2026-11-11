# RC-039 Slice D — test-only accessible HTML Project Hub preview

## Scope and security boundary

This is a responsive **fictional-only, owner-only HTML interface** in a stacked Draft PR. It does not expose a user-ready Project Hub in development or production.

- The prior Slice C JSON GET/POST/PATCH endpoints and return formats remain unchanged.
- Three *separate* HTML paths (GET preview; POST card creation; PATCH versioned transition) are registered inside the existing \`if Rails.env.test?\` route scope. Their controller executes the original \`test_only!\` guard, active DB-backed owner session and \`WorkspaceMemory::ProjectIntakeScope\` client/intake validation for every request.
- The view enumerates the existing four lane definitions and nine fixed document-plan cards. No arbitrary project/client free text, sources, filenames, financial amounts, task descriptions or comments appear in HTML.
- All document generation evidence remains blocked. Creating a synthetic card and choosing a permitted transition only writes Slice B's owner-scoped metadata and immutable state receipt. Stale versions return HTTP 409; invalid transitions HTTP 422; foreign/revoked scope HTTP 404; guests redirect to sign-in.
- Uses Rails \`button_to\` and \`form_with\` for keyboard-accessible, CSRF-protected actions; no drag-and-drop, JavaScript state mutations, real client approvals or unsaved form fields. Existing \`White Atlas\` components and a namespaced \`_rc_project_hub.scss\` create a responsive four-column board collapsing to one column at mobile widths, without a horizontal scrolling rail.

## Verification

- \`test/controllers/studio/synthetic_project_hub_ui_http_test.rb\`: login, scoped HTML, redaction, POST and PATCH mutations, stale and invalid requests, revoked/foreign tenants, production/non-test denial.
- \`test/system/studio_project_hub_browser_test.rb\`: real Chrome at 320/390/430px using CDP CSS viewport, visible controls not clipped, no document overflow; owner creates and moves fictional cards. Browser testing is not yet keyboard-only/screenreader acceptance.
- Exact-head GitHub push/PR CI, Security Audits; owner Linux Mint targeted and full test suite remain the acceptance gates.
- In the owner's isolated \`rails_calendar_rc039_qa\` worktree, \`db/schema.rb\` is modified from the previous test-only migration. Preserve it; no \`db:drop\`, \`db:reset\`, force reset or production deploy.

### Deliberately deferred

Functional development/production Kanban, drag/drop and keyboard reorder, real project tasks, assignments, comments, timeline, project-only calendar, client invitation/consent and audit security for real sources and file exports. These need separate models and E2E review. A test-only HTML route is evidence of interface behavior, not a production capability.
