# RC0551F C2.1e + E1 — compact private AI UX and client service-start pilot
**Date:** 2026-11-18  
**Implementation:** stacked Draft PR #81 `feat/rc0551f-c21c-live-owner-ai-chat-2026-11-18`  
**Scope:** Rails 8.1 / Turbo / Stimulus / PG15+18, source code only. Explicitly not a live customer launch.

## C2.1e owner AI room
- Private conversation title is **automatically initialized from first note** and updated by Grok for a first paid turn, without a separate title input occupying the chat. Via each list item's `… → Rename`, edit the actual item and save on blur/Enter with `PATCH .../title` JSON, CSRF and ownership verification; manual title won't be overwritten by later Grok follow-up. 
- Per-thread menu: archive, restore, **remove to Trash**. This does **not** destroy data, attachments or AI ledger. Migration expands `owner_ai_conversations.state` constraint from active/archived to active/archived/removed, preserves archived_at as a tombstone date, and offers reversible rollback after restoring all removed rows.
- Compact no-thread UI, existing Turbo in-place navigation, no redundant large empty block. Owner-only file delivery stays `no-store` and `nosniff`.
- Attachment allowlist: PNG/JPEG/WebP (2 MiB), PDF (10 MiB), common text/Markdown/source (.txt/.md/.json/.rb/.py/.js/.ts/.yml/.yaml/.xml/.css/.scss/.sql/.sh/.log/.csv), ZIP/7z/RAR/TAR/GZ and Office files (15 MiB). Up to 3 per turn. For **paid AI requests**, only PNG/JPEG and <=24 KiB UTF-8 text formats can be sent with explicit consent; larger text can be stored as a private note up to 2 MiB. No archive unpacking, malware scanning, OCR, code execution or broad provider access. Untrusted formats are delivered as attachment/octet-stream.
- Floating dock: hide redundant subtitle/open arrow, short consent in one line, detailed cost under collapsible disclosure; narrow collapsed "Find with AI" with distinct category icons and **current page navigation only** (files, tasks, archives are future search scope, not working search); "My conversations" shortcut at bottom.
- Four locales: en/ru/hy/es. No full visual system rewrite.

## E1 — one request with zero/multiple published service versions
- Reuses existing verified-client **local fictional pilot**, `ProjectIntake`, `ClientRequestsController`, owner inbox, `ServiceOffering`, `ServiceOfferingVersion` and already approved human spec handoff.
- New optional `project_intakes.workspace_id` FK; new `IntakeServiceSelection` join with unique pair `(intake_id, service_version_id)`, FK and publication/workspace checks.
- `/client/requests/new` shows **only currently published** service versions, multi-select up to six from the **same** workspace; no choice is legitimate for a custom task. If multiple public workspaces exist and the client makes no service choice, they must choose a specific specialist. A version ID submitted after unpublish or from another workspace fails validation.
- For one or more selected services, missing title/project category/goal can be filled with an explicitly **synthetic draft** from known published service facts. These are not accepted requirements or contract scope. `create` persists the exact immutable version IDs in the same transaction as the client-owned intake and messages. Existing non-service local pilot remains functional.
- Client show displays selected published version snapshots, not private owner data; other clients cannot enumerate or read requests. A later catalogue unpublish does not erase historical selected-version IDs.
- No real AI client chat, guest pre-intake, owner invite token, 12-section revision acceptance, client-owned calendar/project, paid order, public data intake or notification automation claimed by this release. E2 owner invitation after separate test is next.

## Tests and release gate
- Model/controller tests cover guest/foreign client ACL, published selection, zero/multi service, invalid/mixed-workspace/stale IDs, explicit consent, localized UI, owner chat JSON rename, archive/trash restore and Markdown+ZIP note vs AI distinction.
- Chrome system tests updated to target the **outer** `#owner-ai-dock > summary` and explicitly open collapsed Find before navigation.
- GitHub CI to verify PG18 scratch fresh schema, migration from published Railway SHA `90d7a81` preserving a synthetic row, full Rails model/controller/browser tests and Security Audit on exact final SHA.
- **Local acceptance:** update only `~/rails_calendar_ai_c21c`, build JS/CSS, check and migrate only the named isolated review database `rails_calendar_rc0551f_c21b_review_20261117`; restart only port 3002 after stopping the old Puma. Test 1: new note with Markdown+synthetic ZIP, edit title via `…`, archive/restore; 2: verified synthetic client opens `/client/requests/new`, chooses a published service, creates a fictitious request; 3: confirm same exact version appears on client detail, owner inbox, and inaccessible to different client.
- **Railway:** this branch has not been merged/deployed. Existing production has no durable owner-chat upload volume, client real-data legal/privacy gate or tested restore of production DB; do not deploy these new database/media capabilities yet.
