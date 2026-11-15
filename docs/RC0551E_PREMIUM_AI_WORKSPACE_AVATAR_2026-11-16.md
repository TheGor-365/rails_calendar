# RC055.1e — Premium AI review workspace + compact square owner avatar
**Date:** 2026-11-16. **State:** implemented in Draft PR #70, pending final HEAD CI and owner desktop/mobile visual acceptance. Parent #69 (RC055.1d). No new migrations, no production change.

## User-accepted brief (screenshots of RC055.1d, 16 Nov)
Owner rejected plain, under-designed AI catalogue page and separate full-width avatar upload panel. Use the already accepted White Atlas style of owner cabinet, practice and service cards. Owner avatar must remain a compact 1:1 rounded-square with a pencil overlay and intuitive editing. Do NOT replace real ACL or billing rules in pursuit of prettier UI.

## Delivered code
- AI review screen now has a compact hero; 3 DB-backed KPIs (private service count, latest suggestions, accumulated AI charges); structured launcher (categories/copy/risk) with real consent checkbox, explicitly billable run button and spending link; an adjacent policy/control rail and linked already-implemented AI actions (catalogue, profile, capabilities).
- Results distinguish no run, run with zero suggestions, and current saved proposals. Server GET filters (all/category/copy/risk/ready) preserve real audit state. Proposals preserve current-vs-AI comparison, expanded rationale/exclusions and manual draft-only application. No hidden auto-approval, no new Grok requests on page load.
- Compact avatar is inside cabinet hero. Pencil icon opens an accessible native details popover; original Active Storage upload and owner ACL remain. Browser Stimulus enhancement center-crops a selected image to a 512x512 JPEG on a canvas before private upload. Square CSS uses object-fit: cover so even an old/original file displays as 1:1; if JS is unsupported, native validated upload remains possible. This is automatic center crop, NOT manual cropping with dragging and zoom.
- Shared owner AI workflow registry + small partial use only real routes. Later generic AI workflows require separate backend service, policy and tests. This slice does NOT implement unrestricted, autonomous AI on every page.
- Scoped new _rc_owner_ai_workspace.scss imported after service offerings. Changes to _rc_owner_cabinets.scss are scoped to avatar; global White Atlas remains intact. RU/EN/HY/ES for new AI page copy; RU/EN for avatar crop.

## Acceptance gates
1. Rails CI + Chrome + Security successful on exact current PR #70 HEAD, with no accidental paid Grok calls in tests.
2. Owner local preview check: /workspace/services/ai at 1440 and mobile 390/320 (no horizontal scrollbar; true 0-suggestion empty state); catalogue and cabinet navigation still work.
3. Avatar at /workspace/cabinet: 1:1 square, rounded, small edit pencil; click pencil reveals form; select a safe synthetic photo, crop status appears, upload, image becomes square in hero and nav; old avatar attachments not deleted. Don't share original private photo to AI or public.
4. Budget/consent: simply visiting AI page is free; only explicit owner POST with checked permission can run paid Grok. No call required for visual QA.
5. Explicit owner visual acceptance before proceeding. No main merge, production migration, Railway deploy or deletion.

## Known limitations
- Client catalogue is NOT live, even if internal service is enabled. RC055.2 handles client presentation.
- Avatar upload is local-only test/development and protected by owner-scoped route; production storage/scan and photo policy must be designed before launch.
- Browser center crop has no drag-to-position UI; add only if owner requests after visual QA.
- Original file bytes, avatar bytes and generated variants are NOT in PostgreSQL backups. Pair pg_dump with a private storage snapshot; Railway ephemeral disk is not durable.
- Last actual paid Grok audit visible in owner screenshot returned zero suggestions; do not treat this as proof all services are optimal. Do not trigger a second paid review without explicit consent.
