# White Atlas — mandatory UI/UX contract (owner-approved 2026-11-15)

Source-of-truth precedence: **actual checked-out ERB/SCSS/Stimulus and CI + newest owner-accepted browser screenshots** > this document > historical design documents. This contract codifies the visually accepted \`/workspace\`, \`/workspace/cabinet\`, \`/workspace/practice\`, and the RC055.1b \`/workspace/services\` screenshot. Do not redesign successful pages.

## Mandatory rules for every new screen and component

1. Reuse existing White Atlas/Workspace layers, **never establish a third global design system**:
   - \`_rc_design_system.scss\`, \`_rc_workspace_surface.scss\`, \`_rc_owner_cabinets.scss\`, \`_rc_ui_consistency.scss\`, \`_rc_service_offerings.scss\` for scoped service features.
   - \`--ws-paper\`, \`--ws-ink\`, \`--ws-muted\`, \`--ws-border\`, \`--ws-teal\`, \`--ws-teal-wash\`, \`--ws-shadow\`, \`--ws-shadow-up\`, \`--ws-easing\`. Use real computed cascade, not old approximate hex values.
   - Use \`.ws-owner-hero\` or \`.rc-page-hero\`, \`.surface-panel\`, \`.ws-account-tool\`, \`.rc-action\`, \`.rc-status-pill\`, \`.rc-input\`, and existing \`rc-select\` for consistent forms. Avoid new global \`h1\`, \`input\`, \`button\` CSS.
2. Card contract: semantic Bootstrap icon 36–42px with mint wash, clear title/subtitle/scope, status only from DB, optional approved owner-private media, and **consistent actions anchored at card bottom**. Text/URLs wrap safely, card heights stretch as needed, no forced truncation of critical content. Default hover \`translateY(-2px)\`, duration about \`180ms\` with \`--ws-easing\`, original \`--ws-shadow-up\`.
3. Visual hierarchy: White Atlas typography \`Inter, "Segoe UI", system-ui\` with compact existing page hero (\`clamp(1.55rem,2.3vw,2.17rem)\`), headings 790–820, muted 0.72–0.85rem metadata, semantic icon groups and readable body. Avoid oversized decorative badges.
4. Privileged data: owner/client/guest are different roles; no client/marketing access to owner profile snapshots, hidden limitations, private offers, files, raw AI prompts, API keys or metadata. Draft \`!=\` approved \`!=\` enabled \`!=\` client-published. AI never publishes, approves or transmits files silently.
5. Disclosure and motion: optional details collapse with smooth, restrained transitions and accessible native \`<details>\` where possible; negative/hard no-go uses **subtle red dot/icon and calm text**, not a whole red panel. Respect \`prefers-reduced-motion\`.
6. Localization, interaction, responsive: RU/EN always, HY/ES when affected by new private owner UI. Native forms and errors work without JS. Test desktop 1440/1280, tablet 768, mobile 430/390/320 with no horizontal scrolling, Tab/Enter/Escape, Focus-visible, Turbo navigation and server-side state changes. All buttons must be functional; there are no decorative actions.
7. Images and media: landscape banner defaults 16:8; owner-only route until audited publication. Every image has context-aware alt text and object-fit. File type + size + owner ACL validated server-side. AI access requires separate per-asset consent and extraction pipeline; no browser upload implies AI permission.
8. Before advancing a UI slice: exact Git SHA, Rails+Chrome+Security CI, new owner desktop/mobile screenshot and explicit visual acceptance. A green test suite does not replace browser acceptance.

## Historical references

- \`docs/RC034C_WHITE_ATLAS.md\`
- \`docs/WORKSPACE_VISUAL_SYSTEM_2026-11-12.md\`
- \`docs/UI_AUDIT_UNIFIED_DESIGN_2026-11-13.md\`
- \`docs/RC052_WHITE_ATLAS_CABINET_CONTRACT_2026-11-14.md\`
- \`docs/RC0532_WHITE_ATLAS_SELECT_MENU_AUDIT.md\`
- Original external handoff \`WHITE_ATLAS_DESIGN_SYSTEM_V1_2026-11-14(2).md\`, owner-supplied 2026-11-15. Its forward-looking components are not automatically implemented.

Any new Rails Calendar contributor/chat starts by reading this contract, the source files and the latest actual UI screenshots.
