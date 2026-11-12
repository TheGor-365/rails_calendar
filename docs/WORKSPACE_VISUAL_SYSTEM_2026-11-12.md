# Rails Calendar · AI Workspace — Visual System v1

Date: 2026-11-12 · Branch: `feat/workspace-visual-system-2026-11-12` · Based on MVP-A (RC-035 code-only release cut).

## Product brief and non-goals

**Objective:** Make this a service/workspace product, not a developer biography or Bootstrap-template landing. Preserve existing White Atlas palette (white / graphite / muted teal). Trello inspires information architecture (workspace navigation, cards, states, columns) but no brand colors, marks, direct visual cloning, or fictional persistence.

**Public domain:** 4 paid-service categories with one honest external contact step and clear scope/acceptance practice. Do not claim live client cabinet, stored briefs, drag-and-drop projects, AI-generated plans or verified client messages.

**Private domain:** Retain owner Calendar Month/Day/Hour, Consultations, Intake Inbox and existing ACLs. New compact app chrome and calendar KPIs use only records already loaded by PagesController#home. No added DB queries or migrations.

## Tokens / components

Public CSS: `public/marketing.css`, source-of-truth `--mk-* ` tokens.
Private SCSS: `app/assets/stylesheets/_rc_workspace_surface.scss` loaded **after** legacy `rc_design_system` so existing geometry/components remain intact. Private tokens `--ws-* `.

- Surfaces: flat canvas, paper card, nested lane with border and controlled shadow.
- Brand: White + charcoal + teal, no large theatrical headline.
- Icons: public, self-hosted SVG sprite `/workspace-icons.svg`; private Bootstrap Icons already bundled.
- Navigation: workspace sidebar on desktop / horizontally scrollable secondary nav on mobile; owner login is separated and route-backed.
- Cards: real anchor hit-targets; hover raise / pressed lower / accessible focus ring / reduced-motion rules.
- Actions: semantic `<a>` for navigation, real `<button>` remains on all forms; slim 40px icon+label controls, not full-bleed Bootstrap CTA.
- Layout: responsive breakpoint 1250/1050/780/560; available width 320+; inner headings scale modestly.
- States: labels represent **a static flow illustration**, not live task status. Counts on the private month view are computed from existing calendar data.
- Access: no anonymous calendar access; no public forms or AI/network execution; no permission changes.

## Product maturity boundaries

- **Available (upon approved deployment):** public four services, process explanation, external Facebook/Kwork profile links, owner-only existing calendar.
- **Demonstration only:** three-column request workflow illustration.
- **Not released:** real client submission, collaborative boards, external AI access, file uploads, client processing inside the app.
- External message deliverability must be tested from another account before production GO.
- Known local issue: isolated preview database `rails_calendar_mvp_preview_20261112` was created but schema load failed because rake processes another unspecified DB adapter; `/services` can render without its tables. Fix preview database isolation before private-flow QA.

## QA gates

1. Exact-HEAD CI: Rails / Chrome integration + security (tests must be read after final commit).
2. Manually open `/services` at 320, 390, 430, 1280; no horizontal overflow, icons visible, focus order correct, no false interactive controls, reduced-motion observed.
3. Owner session and private Calendar/Day/Hour, Consultation CRUD regression before sign-off (isolated DB only).
4. Anonymous production root must remain privacy-safe, no Consultation queries. Static-only assets are publicly accessible.
5. No merge or deploy without owner release authorization, reviewed Railway preDeploy `db:migrate`, and backup/rollback gate.

## Follow-on rollout (separate PRs)

- Real shared components for private list/detail/form/quiz and empty/error states, with Playwright/Capybara visual snapshots.
- Once ACL, tenant scoping and consent are complete: client-facing Request Quiz and actual status board.
- UI localization: marketing RU; existing private screens EN until translations are reviewed.
