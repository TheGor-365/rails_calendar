# White Atlas: banner and contextual workspace contract
Date: 2026-11-25. Status: owner requested direction; first banner slice committed; navigation history design pending implementation and QA.

## Evidence
Owner screenshots on isolated :3003 at 83522ce5 confirm cabinet opens interview in one dialog, parent URL stays cabinet, no duplicate inner global header; profile is still a full page; interview has orphan large icon; practice lacks compact banner and mixes button variants. Do not store private screenshot data in repo. Previous exact-SHA CI passed 519 integration and 57 system tests. Manual acceptance is partial.

## Banner contract
One compact green eyebrow/path and one small icon. No orphan hero icon when h1 is visually hidden; preserve semantic h1. Uniform gradient/border/padding and quiet navigation actions, wrap on narrow screens. Avatar and functional content icons exempt. Keep action emphasis in actual content, preserve all authorization and meaningful validation/consent notices. Practice snapshot informational sentence removed only from view; version semantics unchanged. Initial implementation: cabinet both practice links marked modal, practice compact banner, interview/capabilities orphan icons removed, services compact eyebrow icon, quiet navigation buttons.

## Route inventory from config/routes.rb and current dialog controller
| Group | Canonical full page | Contextual GET candidates | Review |
|---|---|---|---|
| Owner account | /workspace/cabinet | /workspace/practice, /workspace/setup?step=*, /workspace/setup/review, /workspace/practice/capabilities, /workspace/ai | initial banner slice; review/AI activity remaining |
| Workspace | /workspace | contextual detail links | audit entrypoints |
| Catalogue | /workspace/services | /workspace/services/new, /workspace/services/:id, /workspace/services/ai | index first slice; detail/new/AI audit |
| AI | /workspace/assistant | /workspace/assistant/conversations, /workspace/assistant/conversations/:id, operation query | audit dock and forms |
| Activity/library/notifications | /workspace/activity, /workspace/library, /workspace/notifications | same contextual destinations from related records | audit banners |
| Calendar | /calendar/day | /calendar/hour, /consultations, /consultations/new, /consultations/:id, /consultations/:id/edit | current allowlist; audit links |
| Owner requests | /admin/project_intakes | /admin/project_intakes/:id/edit_spec, /workspace/intakes/:id/requirements, /project_intakes/:id/quiz and review | requirements/quiz not in current allowlist; verify ACL then add intentionally |
| Invitations | /workspace/invitations | /workspace/invitations/:id | audit |
| Client | /client/cabinet, /client | /client/requests/new, /client/requests/:id, /client/requests/:id/edit | not currently allowlisted; separate role tests required |
| Public | /, /services | public service detail only where meaningful | preserve marketing H1 and SEO; audit separately |
| Auth/verification | /sign_in, /sign_up, /register, /register/verify, /invite, /admin/login | none by default | top-level only, never embed token claim/auth transitions |
| Diagnostics | /workspace/outbox/health | none by default | audit access, keep canonical |
| Downloads | existing authenticated TXT/media/avatar routes | no dialog history | native browser handling |
This is route-level inventory, not completed visual audit of every template. Consultations and owner/client request routes require role-specific verification.

## Navigation contract
One parent-owned dialog and one active iframe. Global nav stays canonical full page; context links opt into modal. Direct URL/reload retains standalone representation. Inside modal, allowlisted GET destinations push logical history (including same-area GETs and query changes); repeated destination truncates history to existing entry; exact origin parent link closes. Back restores prior logical destination and scroll, X closes entire dialog. No nested full-page iframe. Breadcrumb history is not a second global nav. Local anchors don't push. Distinguish observed committed GET navigation from POST/PATCH/DELETE response redirects; never replay mutation; successful redirects update current entry or explicitly advance workflow. Failed validation stays local. Guard unsaved input and in-flight submissions on navigation/close, with explicit discard; file input contents never serialized. Browser back integration needs dedicated tests before enabling. Unknown routes not silently classified as safe; explicit full-page escape with warning where appropriate. External links open separately; downloads native. Auth/expired session leaves modal to canonical sign-in. Server ACL/CSRF always authoritative. Same-origin + active iframe source validation retained; validate message URLs, use bounded in-memory history, no private form state persisted. Localized title from destination, not stale opener. Restore parent focus and scroll; refresh marked parent projections only after successful writes.

## Implementation sequence
F2.5.3a first banner fixes (committed, CI pending). F2.5.3b enumerate actual templates/links and shared banner component; validate all role groups. F2.5.4a parent history/back + authoritative iframe committed-location handshake, cover native and Turbo GET and redirects; F2.5.4b dirty guard, breadcrumb, browser back semantics, mobile/focus/scroll, auth/ACL and downloads. Use synthetic tests, no paid calls. F2.6a email composer follows. Do not deploy/merge or mutate review/production DB. Local review still at 83522ce5 until safe sync.
