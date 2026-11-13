# RC052 — White Atlas visual contract and separate account cabinets
Date: 2026-11-14
Branch: feat/rc052-owner-intelligence-2026-11-14 (Draft PR #51).

## Source of truth: existing product
- Existing design is **White Atlas / Workspace Surface** from
  `app/assets/stylesheets/_rc_design_system.scss`,
  `_rc_workspace_surface.scss`, `_rc_ui_consistency.scss`, and
  `app/assets/stylesheets/application.bootstrap.scss`.
- Colors come from existing `--ws-*` / `--rc-*` variables; typography,
  elevations, radius, Bootstrap Icons and tappable buttons retain the original UI.
- Scoped new rules ONLY in `_rc_owner_cabinets.scss`, appended after prior imports.
- Do not modify Calendar grid, Consultations, Intake/Quiz, Public Services,
  responsive dock or global form primitives for aesthetic experimentation.
- Every action must link to a real route; do not add decorative non-working buttons.
- Provide RU and EN translations. HY and ES fall back to English until validated.
- Accessibility: labels, visible keyboard focus, semantic links, form checks,
  >=44px choice targets, reduced motion, mobile stacking.

## Navigation and permissions
| Role | Entry | Private modules |
| --- | --- | --- |
| Owner | `/workspace/cabinet` | professional context, six-step interview, skills and no-go policy, AI ledger, workspace |
| Verified client | `/client/cabinet` | email-verified account, requests only for that user if pilot enabled, services |
| Public | `/services` | manually authored public marketing only (no private owner context) |

- `/workspace` remains a **work dashboard**, not a duplicate account cabinet.
- `/workspace/practice` remains a versioned approved context view.
- `/workspace/setup` and `/workspace/setup/review` are private owner AI onboarding.
- `/client` is retained as the legacy client-home route; new client-cabinet
  route renders the same verified-client-scoped controller to avoid duplicate
  account state.
- Client intake is still restricted by `ClientRequestPilot.enabled?`.
  Do not infer full public/client production onboarding from the new cabinet.

## Storage / source of truth
Private professional answers, history, AI suggestions, approved context snapshots,
capability classifications and hard-no-go lists live in Rails PostgreSQL tables
(`workspaces`, `professional_profiles`, `owner_interview_answers`,
`owner_interview_answer_revisions`, `professional_context_snapshots`,
`professional_capabilities`, `work_policies`). AI cost resides in
`ai_spend_entries`. Account identity lives in `users` and revocable
`user_sessions`. The local preview DB is
`rails_calendar_mvp_preview_20261112` via system Unix socket, not Docker QA
nor Railway production. No public/profile sync or backup/restore is implicit.

## Anti-regression gates
- Rails CI, Chrome system tests and Security Audit must be green for exact SHA.
- Confirm owner and verified client access, private account isolation, all
  6 interview forms, manual approval, and previous public routes.
- Confirm that original styles and JS builds remain unchanged beyond one
  isolated import.
- Browser screenshot check at widths 1440, 768 and 390 px after local restart.
- Do not deploy preview data or expose Grok key to GitHub / Railway.
