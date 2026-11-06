# RC-014 — Mobile one-thumb navigation / Slate & Tide (2026-11-07)

**Decision:** Keep Rails Calendar's desktop information architecture but make mobile operation thumb-accessible and consistent. Visual inspiration is the bottom five-icon navigation pattern in the owner's Reflect screenshot; do not copy Reflect's colors or business features.

## Design contract

- Below 768px: fixed bottom dock with five **real** actions: **Month** → root; **Today** → today's 24-hour schedule; central **+ / New** → new consultation if administrator is authenticated, otherwise → administrator sign-in; **Records** → consultation index; **Admin** → sign-in (guests) or **Sign out** (admins).
- A guest never reaches write actions by bypassing controller guards. The center plus has an explicit accessible name `Sign in to add a consultation` when signed out.
- Desktop navigation stays in the header. Small-screen header keeps the brand and removes duplicate desktop tab links.
- The dock uses existing pinned Bootstrap Icons, text labels, Slate & Tide green/ink/neutral tokens, focus indicators, 44+px touch targets and safe-area inset padding. Reserve page bottom padding to keep all content scrollable above it.
- Consultation details use **one uninterrupted horizontal row** of 2 or 3 navigation buttons. At 320–430px, labels shorten to `Calendar`, `Final day`, `All`; original full names remain the accessible labels. Authenticated Edit and Delete are separated into a second two-column management row, not mixed with navigation.
- Explicit rule: **mobile parity means every desktop action and feedback path remains reachable, clearly labeled and functional; layout may change but capability must not be lost.** Do not add inert icons or inaccessible overflow.

## Verification

1. CI and Security Audit SUCCESS on the *final* head commit. Server assertions cover five destinations, guest/admin create gate, independent show actions, and admin-only Edit/Delete.
2. Chrome system tests at 320, 390, 430 CSS px check: fixed dock, no document horizontal overflow, no hidden action rail, 3 primary buttons in one row, bottom content inset, guest plus → login, admin plus → new form, admin sign-out.
3. Manual owner screenshots of 320/430px consultation detail and month; icons render and labels readable, no overlap with long timeline, keyboard navigation works. Check dynamic browser toolbar and iOS/Android safe-area behavior on real hardware if available.
4. Keep current `main` and Railway untouched. The historical Draft PR chain #1→#14 remains stacked; #4 is **SUPERSEDED/DO NOT MERGE**.
5. Next stage after acceptance: manual admin CRUD and security/access checklist, then explicit timezone policy/ADR. AI Intake comes after P0/P1 gates.

## Known development console note

Chrome DevTools can request `/.well-known/appspecific/com.chrome.devtools.json`. A corresponding Rails RoutingError is a harmless browser discovery probe, not a calendar error. Never turn off exception logging globally to suppress it. Treat separately only if the owner wants a targeted noise reduction after functional QA.

## Links

- RC-013 (previous): https://github.com/TheGor-365/rails_calendar/pull/13
- Development roadmap: https://github.com/TheGor-365/rails_calendar/blob/feature/rc013-slate-tide-icon-actions-2026-11-07/docs/RAILS_CALENDAR_DEVELOPMENT_ROADMAP_2026-11-07.md
- Notion checkpoint: https://app.notion.com/p/4102cdc8e76581eaa500d6aab39996a6

## RC-014b: failed visual acceptance and corrective revision — 07.11.2026

**Owner screenshot (source: current CAREER chat, approximately 00:48 local):** 430px Chrome-emulated month shows bottom navigation as flat, underlined links located at the end of scrolling content instead of a floating dock. That screenshot **rejects RC-014 visual acceptance** even though prior GitHub CI and Security were green. The rendered HTML proves the mobile partial is present, but not that its current stylesheet loaded. It is not yet possible to distinguish local stale Sass bundle/browser cache from another browser-specific issue without local loaded-asset readback.

**Implemented RC-014b response in the same PR #14:**
- Centered dock: `position: fixed; left: 50%; transform: translateX(-50%); bottom: 0; width: min(100%, 430px); z-index: 1100;`, 5 equal grid columns.
- Refined Slate & Tide surface, border, background blur, shadow, stronger icon hierarchy, centered labels, active state, raised shaded `+`, safe-area padding and body bottom reserve.
- Keep independent guest/admin `+` destinations, server-side access checks and separate admin management row; no extra JavaScript or icon dependencies.
- Launcher rebuilds CSS **and checks** `--rc-mobile-dock-release: rc014b-20261107` in `app/assets/builds/application.css`; exits if missing. A local asset can still be browser-cached: Chrome hard reload with DevTools Disable cache required if plain underlined links remain.
- Chrome system regression checks loaded CSS marker, Bootstrap icon pseudo font, the dock's fixed position, center alignment and max-width at 320/390/430px, plus fixed viewport bottom **after scrolling a long day**.

**Release status:** branch/PR code pending fresh final-SHA CI/Security and owner screenshots; do not describe RC-014 as visually accepted until dock is visibly pinned. Do not merge/deploy Railway. **Next**: local screenshot at month and consultation details, 430px and 320px; then P0 admin create/edit/delete of a newly created test record, access-control/manual security checks, timezone ADR.
