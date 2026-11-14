# RC054.1 — White Atlas client request detail contract
Date: 2026-11-14. Base: RC053.2 SHA d447ce5b039ab528797f65e53d4bf6872283b0e1.
Scope: \`/client/requests/:id\` only. Draft PR; no merge or Railway release authorization.

## Source and invariants
- Existing layout primitives: \`rc-page-hero\`, \`surface-panel\`, \`rc-status-pill\`, \`rc-empty-state\`, \`rc-record-list\`.
- Add only an opt-in \`wa-client-request\` reading surface and shared \`shared/white_atlas/spec_section\` partial. No global typography, calendar or consultation changes.
- Model/controller/routes, client ownership query, local loopback feature gate, review POST and version conflict are untouched.
- Status chips reflect stored request status, type and published spec revision. They do not claim a completed deal.
- \`@spec\` is exclusively \`published_spec\`; AI/owner drafts are not rendered. Five optional document sections display only non-empty items as escaped text, not raw HTML. Narrative line breaks wrap safely.
- The review CTA records **read receipt only**, submitted with published revision version; not contract/scope/price acceptance.
- Milestones only come from controller's published revision and remain explicitly tentative.

## Acceptance before moving to RC054.2
1. Exact-SHA Rails, Chrome and Security workflows PASS; inspect CI logs, not only badge.
2. Client A can read own request; client B gets 404; anonymous redirects; owner-only draft never leaks; CSRF/version guard preserved.
3. Visually capture desktop 1440/1280, tablet 768, mobile 430/390/320: summary, multiline long text, pending spec, approved sections, read receipt, tentative milestones, top/middle/bottom; no sideways scroll.
4. Keyboard Tab/Shift+Tab and visible focus; text scale; contrast; Turbo navigation; four locales.
5. Compare old accepted \`/workspace\`, \`/workspace/cabinet\`, calendar and consultations to baseline; **do not** redo these pages.
6. User explicitly accepts local UI screenshot before RC054.2 or AI-first features proceed.

Blocked outside this PR: local Mint checkout/process state not accessible to GitHub connector, preview DB identity/restore, real-browser screenshots, production restore. Do not redeploy.
