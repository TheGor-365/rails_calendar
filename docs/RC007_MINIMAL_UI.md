# RC-007 — Minimal UI and consultation date validation

Date: 2026-11-06.
Status: Code in an isolated branch; CI and manual QA pending.
Base: RC-004 Draft PR #6. No changes to main or production.

## Minimal design system
- Neutral background #f8fafc, white surface #ffffff, border #e2e8f0, primary accent #4338ca.
- System UI typography with legible hierarchy and whitespace, no decorative gradients.
- Bootstrap/Turbo, keyboard focus, responsive forms and horizontal mobile calendar scrolling.
- Do not introduce Vite/Capacitor until a separate architecture ADR defines both web and mobile clients.

## Scope
- Consistent nav, header, form and detail page.
- Server-side consultation year bounds: 2000–2100.
- Title max 120, description max 5000, min/max date input hints.
- Existing authorization: public read; admin-only mutation. No new roles.

## Manual acceptance
1. Update a separate local checkout to RC-007 and verify desktop/mobile calendar, forms, focus, scrolling.
2. Admin create/update/delete with valid current dates. Verify rejected 1212/2101 years and end before start.
3. Sign out; public browse remains available; unauthorized mutations remain blocked.
4. Capture test logs, branch SHA and screenshots. Leave PR Draft until verified.

Out of scope: client intake, AI pipeline, booking, Vite, Capacitor, public deployment, database migration.
