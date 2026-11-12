# Rails Calendar · UI Audit & unified identity experience
2026-11-13 · Draft PR visual hardening on top of Draft PR #44. No deploy.

## Evidence-based scan

Reviewed the **39 application ERB view and partial files** in the 2026-11-12 client signup branch, plus app layout, the 43KB Bootstrap+custom SCSS bundle, `_rc_design_system.scss`, `_rc_workspace_surface.scss`, app helper for icon labels, account controllers and ActionMailer configuration. Primary screens: public /services, /sign_in, /register, /register/verify, /sign_up (local only), /admin/login, /workspace, /client, calendar month/day/hour, consultation list/forms/show, project-intake/quiz/review. The existing component language already relies heavily on `rc-*` classes; Bootstrap is mostly grid/utilities. No full UI rewrite is warranted or safe before owner/calendar E2E.

### Specific issues found

1. **Critical visual fragmentation**: `/sign_in` and legacy admin/owner bootstrap use `application.html.erb` and application SCSS, but `/register`/verify/privacy use `signup.html.erb` and standalone `marketing.css`; logo, nav, forms, spacing, button and responsive behavior vary. Fixed via shared `account.html.erb`, `_account_heading.html.erb`, `_rc_account.scss`.
2. **Misleading mail UX**: Development uses `config.action_mailer.delivery_method=:file`, so the message **never reaches Gmail** even when /register/verify says it was sent. Now local verify view explicitly states the message is stored under `tmp/signup_emails` and not delivered externally. Production SMTP contract in PR44 remains feature-gated, not activated.
3. **Naked text links and missing icon semantics**: Login/signup/verify had inconsistent naked inline links and unadorned submit, while calendar/owner pages already use `rc_icon_label`. Shared compact icon+label actions now use native links/buttons and accessible names. Do not replace with icon-only unlabeled controls.
4. **Inconsistent UI materials**: white surfaces and slate/teal palette are already stable, but component states are defined in scattered SCSS layers. New scoped `_rc_ui_consistency.scss` consolidates focus/hover/disabled behavior without touching calendar time grid, consultation routing, or quiz state machine.
5. **Spacing & CSS layering risk**: 43KB application SCSS followed by `_rc_design_system.scss` then `_rc_workspace_surface.scss`; duplicative rules remain. Phase 2 should consolidate tokens and strip duplicate selectors **after** test and visual baseline; broad deletion now risks RC-039/private calendar regressions.
6. **Known remaining low-priority spots**: page-day positioning/quiz progress use a few inline dynamic styles, responsive quiz actions still stretch to 100% in some flows. Retain functional hit targets and progress indicators; prioritize targeted visual refactors with browser tests.

## Design language v1

Palette: existing `#fff`, `#172d37`, `#0a766d`, `#e7f6f2` (White Atlas).
Components: brand mark, compact nav chips, intro label/icon, bordered surface panel, labels/inputs, small icon+label submit/link, status note, focus ring. Default 40-45px touch targets and 10-17px radii; medium quiet shadows. Semantic links for navigation and buttons for writes; no Bootstrap btn/card/alert. One layout for sign in, signup, OTP, owner bootstrap and legacy admin.
Accessibility: keyboard focus, label-to-control, 320px+, reduced motion, no API/secret exposure in UI.

## Live email / production gate

- Current QA is **file delivery only**. Message contents may include the six-digit code, therefore do not commit, screenshot, paste, publish, or upload mailbox files. `tmp/signup_emails` must be excluded from git and cleansed after QA.
- To send a real Gmail message, an SMTP sender/provider and verified domain/config must be set up. Do not pretend writing a local file is delivery. Never request or put SMTP secrets in chat/repo.
- Production registration remains NO-GO pending live SMTP and bounce checks, password reset, data privacy/deletion, backup/restore, migration safety and isolated tenant ACL.
- The optional production SMTP setup already implemented in PR44 is off until all release gates are approved.

## QA gates / staged rollout

P0: Automated Rails/Chrome/security against exact branch SHA; verify /sign_in, /register, /register/verify, /admin/login all show shared chrome. Confirm that signup role cannot access /workspace.
P1: Visual local 320/390/430/1280, keyboard and pointer states, long email/password validation errors, real owner login and no ghost guest actions.
P2: Calendar/consultation/quiz/mobile UI baseline snapshots, then targeted component refactor based on visual delta; no wide-ranging business logic changes.
P3: Real SMTP sender setup and recipient delivery test, policies and password recovery. ONLY THEN consider production feature release.
