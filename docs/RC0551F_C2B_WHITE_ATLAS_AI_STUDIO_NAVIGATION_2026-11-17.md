# RC055.1f C2b — White Atlas owner AI Studio visual correction & navigation
Date: 2026-11-17 · Parent: Draft PR #74, exact base SHA `ff77591ed29e2899c752c185f862f3516a357847`.
Status: design/code in NEW stacked Draft PR, subject to exact-head CI + owner visual acceptance. No DB migration, AI call, auto-apply, client release, production merge or Railway deployment.

## Owner evidence
Owner sent a desktop screenshot of `/workspace/assistant` showing a flat, same-sized 2×2 knowledge-card grid with little hierarchy and described it as **too Bootstrap-like/primitive**. Owner also noted no discoverable direct route to this page from top navigation or floating panel. Local owner terminal confirms **clean** checkout of parent C2.0 branch at `ff77591`, `bundle check`, `yarn build`, `yarn build:css`, `bin/rails restart` success. Screenshot proves the C2.0 knowledge card renders with profile v1, 9 private / 9 approved offerings, FAQ not structured, documents not connected; does not prove full mobile visual acceptance.

## Design contract followed
User-provided `WHITE_ATLAS_DESIGN_SYSTEM_V1_2026-11-14.md` plus repository docs `RC034C_WHITE_ATLAS.md`, `WORKSPACE_VISUAL_SYSTEM_2026-11-12.md`, and current compiled SCSS sequence. White-first paper surfaces, existing `--rc-*`/`--ws-*` tokens, restrained teal, Inter/system fallback, icon+text controls, 44px targets, one H1, semantic HTML, no global Bootstrap/layout overrides. Do not restyle accepted owner cabinet/calendar/consultations, public /services marketing layer or client flows.

## Implemented in C2b
1. Prominent `AI Workspace` entry in **owner desktop main navigation** with real active state/aria-current. Mobile has a compact top-header shortcut (the existing 6-position mobile calendar dock stays intact; do not add cramped seventh item).
2. Floating AI panel contains a **large, descriptive AI Workspace link near the top**, above paid generator. Its old tiny duplicate footer link is removed. Link is always GET/free and owner-gated.
3. Owner AI Workspace page hero is a bespoke compact White Atlas editorial surface (soft gradient, semantic icon, honest privacy/review notes, back to cabinet), followed by an accessible, mobile-wrapping **on-page wayfinder** to draft creation, actual knowledge inventory, saved draft history and private service catalogue.
4. Knowledge panel is a readable **asymmetric source board**, not four identical Bootstrap cards. Leading feature shows only owner-approved-profile readiness and factual 3-stage consent/review process; service catalogue tile shows real private/approved counts (not automatically sent); FAQ tile honestly says knowledge is missing; full-width lock-style document tile says AI access is disabled. No fictional "percent complete" or fake controls.
5. Scoped CSS only in `_rc_owner_ai_assistant.scss`, reusing existing `rc-action`, `surface-panel`, bootstrap icons and named helper; RU/EN/HY/ES translations.
6. Rails tests: owner-only nav/launcher links, inaccessible to client, correct anchor targets, no paid ledger writes. Chrome 1440/390/320 test for owner nav, mobile header, floating shortcut, anchor targets, no horizontal overflow and four source cards.

## Distinctions & remaining gates
- This is presentation/discoverability. It **does not** turn the passive map into a live client advisor. Full owner FAQ/cost knowledge collection, documents and per-client contracts remain planned stages.
- Desktop and 390/320 screenshots from the owner's actual browser are required for visual signoff: top hero, source board, floating panel open, keyboard/scroll. CI is not a substitute for visual acceptance.
- Fixed 46px mobile launcher occasionally overlays underlying help text; track as separate P2 unless verified repaired. Do not hide the launcher on this route.
- No persistent conversation migration before verified new PG16 + private storage backups and isolated restore. Production release requires explicit owner approval and PR ancestor audit.
