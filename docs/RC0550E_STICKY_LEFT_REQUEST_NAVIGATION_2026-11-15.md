# RC055.0e — Sticky request-detail section rail (2026-11-15)

Owner accepted the visual snapshot of RC055.0d and requested a fixed left section navigator.
This is an additive presentation/UX refinement on Draft PR #63 SHA `6635029cd1377632d9cd713993c7a9163c206985`, **no migration, auth change or AI call**.

## Contract
- Both client `/client/requests/:id` and owner `/project_intakes/:id` use one reusable left navigation component, made of native anchor links and real section ids. No duplicated top jump navbar.
- Desktop >991.98px: sticky panel in the content grid, anchored below existing app header, with a bounded independently scrolling menu if necessary.
- At tablet/mobile widths <=991.98px: panel becomes static and a compact *wrapping* horizontal row. No page-level horizontal overflow at 320/390/430.
- A Stimulus scrollspy decorates the active anchor with `aria-current=location`. Navigation still works without JavaScript. No observer/server write, and no scroll state is persisted.
- Permissions/conditionals control available links. Client gets only: current facts, original, conversation, reply if allowed, published spec/pending notice, and milestones if present. Owner gets the lifecycle, original, conversation, owner review and visible spec/calendar when available.
- The current saved snapshot and latest client turn remain visible, and expanding the history does not change owner read receipts.
- Bootstrap Icons are existing dependency. RU/EN/HY/ES translation keys. No change to release gate.

## Required verification
- Exact-SHA Rails + Chrome + Security CI, nav href/target test and Chrome scroll/sticky/mobile layout test.
- Local owner and client screenshots on 1440 desktop; scroll deep to verify sticky rail and active section; 320/390 responsive with keyboard navigation.
- All PRs Draft stacked; no merge, Railway production or paid Grok.
