# RC054.3c — specification editor navigation and unrestricted native textarea growth
Date: 2026-11-15, stacked on Draft PR #57 exact base `5cd01054cf4e3f486f3da3070ccf00e3fe629b65`. No production deployment or DB changes.

## Based on user visual QA
- User confirmed textarea auto-grow but found the CSS cap of `min(48vh, 420px)` too restrictive.
- Owner specification edit view had six near-identical long textareas, little categorical information and no search/filter, making larger projects hard to navigate.

## Change
- Opt-in `wa-autogrow` now has no hard CSS max-height. Native fields still keep `maxlength`, validation and original values; browser/document vertical scrolling remains normal, no horizontal overflow.
- Add distinct White Atlas cards: overview / scope (goals, deliverables) / verification (acceptance) / risks (unknowns, exclusions). Each shows label, line count and brief edit guidance.
- An anchored section index is always available without JavaScript. Stimulus `wa-spec-review` reveals client-only search and group buttons; filters temporarily hide sections without deleting inputs, replacing data or making API requests. Includes search by current unsaved field text; Escape clears search.
- No schema, ACL, source/provenance, version semantics, spec approval, price or milestones are altered. The UI retains `review[...]` names and existing PATCH route. Legacy synthetic tests remain.
- Locales: EN, RU, HY, ES.

## QA
- Exact-SHA Rails/Chrome/Security and JS/CSS builds.
- Owner visual at 1440/768/390/320: distinguish each category, search, clear search, anchors, keyboard navigation, full multiline input and mobile overflow.
- Ensure hidden sections retain unsaved values on filtering and POST. No auto-save: navigation away before submission remains a normal unsaved form risk; a future draft-rescue phase must address it.
- No automatic spec publishing. Owner approval separate. Client cannot open owner spec editor.
