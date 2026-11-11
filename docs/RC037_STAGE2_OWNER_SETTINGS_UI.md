# RC-037 Stage 2 — owner-only local AI Settings (no provider calls)

Adds a White Atlas Rails ERB Settings page at \`/workspaces/:workspace_id/project_intakes/:id/ai_settings\` (GET/PATCH).
Only signed-in workspace owners with active membership and an assigned intake can view or change the configuration, and only in Rails test or explicitly opted-in synthetic development. Production returns 404 regardless of flags.

Two independently stored levels: workspace default upper bound and project restriction. Form edits **only** mode and the tiny typed allowlists (\`document_plan\`, \`synthetic\`). Project switches cannot enable anything denied by the workspace. \`reviewed_provider\` is a **configured-but-inoperable** mode; no external model SDK, credential collection, provider invocation or token billing exists.

Token and USD limits remain nonnegative DB-backed configuration fields (zero defaults). There is no paid provider, accounting reservation, real client consent processing, production enablement, real source access or automatic document generation.

Security: owner-only HTTP, scoped project, form CSRF as normal Rails, no-store/no-referrer/nosniff, invalid mode/scope 422, no rendering raw user content, no public/client Settings. Synthetic HTTP tests include guest, foreign owner/workspace, revoked membership, production gate, readback and project-downscoping.

Next: provider/model registry and offline per-purpose controls + explicit accounting reservation design (still $0); UI smoke in Chrome at 320/390/430 after exact-head CI. No Railway changes, merge or real customer files.
