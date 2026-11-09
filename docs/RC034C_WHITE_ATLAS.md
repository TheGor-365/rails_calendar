# RC-034C · White Atlas — Rails Calendar UI design system

Date: 2026-11-09. Scope: existing Rails Calendar worktree at RC-034 Quiz MVP. No controller/model/migration/route/schema changes.

## Design principles

1. **White-first**: raised white surfaces on almost-white background, with whitespace and layered shadows. Avoid boxy border outlines on active cards.
2. **One action language**: Bootstrap Icons (already installed) plus a *visible name* for every interactive action. Never use an icon alone as the only accessible instruction.
3. **Observable progress**: workflow and Quiz stepper show current, saved, missing states; saved data is clearly distinguished from unsaved edits.
4. **Progressive enhancement**: Turbo Drive remains the navigation layer, Stimulus supplies immediate choice feedback and pending-form states. Without JS the form still submits to Rails.
5. **Preserve domain state**: draft ≠ approved specification, proposed milestones ≠ confirmed booking; synthetic intake ≠ paid client contract.
6. **Mobile first and keyboard accessible**: 44px minimum interactive heights, visible focus, responsive stepper, reduced-motion preference, semantic headings/regions.

## Source of truth

- Tokens, layout and components: `app/assets/stylesheets/_rc_design_system.scss` imported *last* by `application.bootstrap.scss`.
- Icons: pinned Bootstrap Icons via existing Sass import; no remote CDN or new font downloaded.
- Actions: `ApplicationHelper#rc_icon_label`, `rc_responsive_icon_label` (already present).
- Reusable process map: `app/views/shared/_workflow.html.erb`.
- Dynamic choice state: `app/javascript/controllers/quiz_live_controller.js`; no API costs, no client storage or background autosave.
- Turbo submit indicators: `app/javascript/controllers/ui_feedback_controller.js`; do not claim successful server changes before Rails confirms them.
- Favicon / error fallback: `public/favicon.*`, `public/apple-touch-icon.png`, `public/404.html`, `422.html`, `500.html`; error pages use inline CSS/SVG so they remain available if Rails/database fails.

## Tokens

| Token | Intent | Value |
|---|---|---|
| `--rc-ink` | Primary text | `#152b35` |
| `--rc-muted` | Supportive text | `#647884` |
| `--rc-accent` | Primary action, progress | `#0a766d` |
| `--rc-accent-wash` | Selected state and gentle emphasis | `#e7f7f4` |
| `--rc-ground` | Page canvas | `#f8fafb` |
| `--rc-paper` | Interactive surfaces | `#ffffff` |
| `--rc-radius-md` | Large surface radius | `22px` |
| `--rc-shadow` | Low-elevation cards | Soft layered shadow |

Base type is system/Inter fallback; never depend on Google Fonts being online. Headings use responsive sizing, tight but readable line-height; body copy 1.55. Visible labels and descriptive icons are paired in navigation/actions.

## Component API

- `.surface-panel` — section card with elevation; keeps existing Bootstrap spacing utilities.
- `.rc-action`, `.rc-action--primary`, `.rc-action--quiet`, `.rc-action--soft`, `.rc-action--danger`, `.rc-action--small` — button/link primitives. Use the `rc_icon_label(icon, label)` helper when generating a new action.
- `.rc-page-hero`, `__content`, `__heading`, `__symbol`, `__actions` — title/action hierarchy; group intro text within `__content`.
- `.rc-status-pill`, `--muted` — supplementary status; not a substitute for rendered server status.
- `.rc-flow`, `__steps`, `__step--current` — domain process map. Highlight only the real state available in view data.
- `.rc-empty-state`, `__icon` — result-less views.
- `.rc-quiz-progress`, `.rc-quiz-meter`, `.rc-quiz-step*` — QA intake progression, labels, saved vs active.
- `.rc-quiz-choice` — selectable, full-width options with matching visual checked state.
- `.rc-quiz-live-state` — unsaved edits indicator, *not* a persistence confirmation.

## Installation and acceptance gates

1. Apply bundle with preflight checks and external backup; no database interaction.
2. `npm run build && npm run build:css`; verify both `application.js` and `application.css` are current, including the `rc034c-white-atlas-20261109` marker in compiled CSS.
3. On local server verify Home / Day / Hour / Consultations, New/Edit/Details, Inbox, Intake, Quiz/Review; mobile widths 320/390/430. Confirm 404/422/500 status via controlled tests, not by visiting the static HTML page (that itself returns 200).
4. Verify owner-only authorization, draft revisions, Ruby/DB identity, quiz targeted + full Rails/system tests. No commit, push, merge or Railway deployment before QA.

## Explicit limitations

- The design implementation covers all **provided** templates and global SCSS/JS. Other account/registration templates not included in the submitted archive inherit the tokens but have not been individually reviewed.
- Existing Turbo Drive minimizes full browser reloads; this release **does not** rewrite every endpoint into Turbo Frames/Streams or add background autosave.
- Client-side `beforeunload` warning is browser-dependent. The four Quiz save actions are still the authoritative persistence mechanism.
- No live app/browser rendering, compiled asset build or Rails test execution was possible in the packaging environment; complete those gates locally.
