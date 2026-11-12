# RC-039 Slice A — fictional read-only Project Hub board contract

**Status: test-only proof-of-contract, not a usable Project Hub UI.** A separate stacked Draft PR builds on accepted automated RC-038 A–G. No project board, real work card, client assignment, milestone, calendar event or artifact is persisted.

\`Studio::SyntheticProjectHubBoardPreview\` revalidates active **owner + workspace + client + intake** every call and refuses production, development, missing explicit synthetic opt-in, cross-client lookups and revoked memberships. The returned deterministic board ID is a display coordinate, not an access credential. Project title, goal and client display name never appear in the response.

The existing deterministic \`Studio::DocumentGenerationPlan\` is the only card catalog. Its **nine** artifact prerequisites populate four stable lanes — Discovery, Definition, Planning, Handoff — with explicit unmet evidence links. All cards remain \`blocked_unverified\` for generation regardless of previous owner triage receipts. No client confirmation, task transition, project scheduling or document approval is inferred. The empty project-calendar placeholder is explicitly independent of the consultation calendar; no dates are synthesized.

This slice intentionally **does not** implement HTML/Turbo routes, drag-and-drop, actual tasks/epics, assignments, comments, milestones, deadlines, critical path or timeline. Those require separate data models, tenant-scoped mutations, policy tests and manual acceptance. It also cannot accept real customer files or invoke external AI and paid providers.

### Acceptance gates

- Run \`bin/rails test test/services/studio/synthetic_project_hub_board_preview_test.rb\` using only isolated localhost \`ruby_calendar_test\`; run the full suite afterward.
- Validate exact-head GitHub Rails CI/Security before counting automated acceptance. This is not an E2E/a11y acceptance of an actual board.
- Keep RC-038, RC-037 and earlier stacked Draft PRs unmerged and unchanged. Never deploy or reset local working trees.

Production requires reviewed identity, consent, encrypted private storage, malware scanning, completed backup/restore and an explicit release decision before handling real client content.
