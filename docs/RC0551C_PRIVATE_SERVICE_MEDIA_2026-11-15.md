# RC055.1c — private service media pilot (2026-11-15)

## Status and scope
- Stacked Draft PR, parent RC055.1b, no production change.
- Add **My services** to owner cabinet quick tools: \`/workspace/cabinet\` -> \`/workspace/services\`. Reuse \`.ws-account-tool\` as defined by White Atlas, never introduce another visual system.
- Version-aware owner attachments to service offerings: banner, image, PDF/text document, audio and video.
- Each media record points to a specific immutable \`ServiceOfferingVersion\`; owner review and archive are separate, audit-preserving actions. This does **not** rewrite the approved service text, automatically enable an offer, or expose it to clients.
- Uploads/downloads enabled ONLY in development on loopback and in isolated test. Production has no media access/release gate, even if this code is eventually deployed.
- No AI provider can read uploaded bytes in this slice; \`ai_access_allowed = false\` and \`can_be_processed_by_ai? = false\` by default. A later stage must implement per-asset consent, sanitized extraction, cost/privacy limits and audit logging before AI analysis.

## Storage and security
- Adds Active Storage backing tables with migration \`20261115220500\` and model \`ServiceOfferingMediaItem\`.
- Direct Active Storage public redirect/proxy routes disabled globally via \`config.active_storage.draw_routes = false\`.
- Owner file reads use ONLY \`GET /workspace/services/:id/media/:media_id/file\` after current account/workspace/offer/item authorization. No signed public blob URL, CDN or public previews.
- All media mutations are CSRF-protected Rails POST/DELETE, scoped to the current owner's \`Workspace\`.
- Allowed types:
  * Banner: JPEG, PNG, WebP <= 8 MiB
  * Image: JPEG, PNG, WebP, GIF <= 8 MiB
  * Documents: PDF, plain text <= 10 MiB
  * Audio: MP3, Ogg, WAV, M4A <= 20 MiB
  * Video: MP4, WebM <= 25 MiB
- Cross-check media category, MIME and extension. Do not support SVG, HTML, arbitrary XML, executable archives. Files served as attachments except inline supported images, always with \`nosniff\` and \`Cache-Control: private, no-store\`.
- No antivirus, transcoding, image resizing or streaming Range support yet. This is **only** local/trusted development QA, not a release-ready user-generated-content service. No real customer documents or secrets during pilot.
- Archiving hides gallery and blocks reads but retains blob and DB record: no destructive purge.
- Note: local \`config/storage.yml\` stores upload bytes in \`Rails.root/storage\`; database dumps do NOT contain file bytes. Future backup/restore must include database + storage together, or migrate to an explicitly chosen durable object store (Railway local filesystem is not a durable media store).

## Acceptance gates
1. Existing 9 offers and 2 manually finalized offers remain unaffected; RC055.1b must be visually accepted.
2. Take a fresh exact preview PostgreSQL backup via PG16 \`pg_dump -Fc\`, list archive, restore it into a new isolated database, compare counts. Never run migrations against Railway or \`main\`.
3. Checkout exact RC055.1c SHA only after clean working tree; confirm \`RAILS_ENV=development\` DB \`rails_calendar_mvp_preview_20261112\`, \`/var/run/postgresql\`, role gor. Then apply migration (new Active Storage tables + media_items).
4. Build CSS/JS, restart preview, visit owner cabinet and \`/workspace/services/1\`. Confirm icon card link, media form, 1 synthetic tiny PNG upload, inline thumbnail, review badge and download. Test wrong user/guest cannot fetch. Confirm \`/services\` unchanged and no AI calls.
5. Rails, Chrome and Security CI PASS on exact SHA, plus desktop and mobile 390/320 screenshot. No public or live file sharing in this slice.

## Next
- RC055.1d or RC055.2: private media version UX refinements, one approved banner selection, reusable owner-only media repository, AI access permission per file and extraction sandbox.
- RC055.2: sanitized client-facing approved offer catalogue and service picker with \`Other\` fallback, published-only *approved* media, no private provenance/owner policy.
- RC056: budgeted Grok qualification, minimum-data dispatch and manual fallback.
- RC057: versioned scope/proposal owner approval; RC058 client workspace/files/calendar; RC059 explicit production release gates, durable storage and restore drills.
