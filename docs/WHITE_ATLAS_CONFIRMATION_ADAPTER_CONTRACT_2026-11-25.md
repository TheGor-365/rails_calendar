# F2.5.5f.2 — White Atlas Confirmation Adapter contract (2026-11-25)

Status: design only; no runtime implementation or acceptance. Baseline PR #81 at 74c475a; corrective test SHA 87cafc2 awaits CI #45520914113 and Security #45520914108. Do not expand runtime code before the repair gate is green.

## API and ownership
- Promise<boolean> request with explicit kind, localized title/message/approve/cancel and source context. Default false on missing dialog, exception, cancellation, teardown, stale source or competing request. Never implicitly approve.
- One active request per document. Reuse the existing White Atlas dialog styling and safe cancel focus; preserve the contextual parent guard's source-document check. Separate lifecycle from navigation. Render text via textContent, not HTML; do not log or persist messages, form fields or consent.
- Native dialog cancel/Escape/backdrop and Turbo before-cache/teardown resolve false and release listeners. Restore focus to connected opener on cancellation; no focus jump to detached node.
- For iframe-originated requests explicitly verify whether the local dialog is usable at constrained viewport size before considering parent mediation. Any parent mediation must check same origin, active frame, source document and request identity; no arbitrary navigation or mutation commands.
- Keep native beforeunload for actual document exits; do not suppress it globally. For quiz Turbo navigation preventDefault synchronously, capture intended same-origin GET destination and source snapshot, and resume at most once after approval with an exact one-shot bypass. Reject stale snapshot/source or superseding navigation. Never use submit state to bypass dirty protection for unrelated operations.

## Integration inventory (verified source at baseline)
| Site | Kind | Invariant |
|---|---|---|
| app/javascript/controllers/quiz_live_controller.js beforeVisit | discard | Cancel retains draft; one approved Turbo GET; native beforeunload remains |
| app/javascript/controllers/wa_invitation_ai_controller.js apply | overwrite | Capture old input and candidate; verify both still current before applying; no network |
| same controller useClientPreview | overwrite | Capture candidate and field; reset share checkbox only on approved actual replacement; no network |
| app/views/consultations/show.html.erb | destructive | Preserve localized ID/title/time warning and DELETE submitter |
| app/views/owner_ai_conversations/_conversation_item.html.erb | destructive | Preserve removal semantics; no request on cancel |
| app/views/owner_catalogue_ai/index.html.erb | bulk | Preserve count, entry_id and fingerprint |
| app/views/owner_service_offerings/index.html.erb | bulk | Preserve count, fingerprint and approval guards |
| app/views/owner_service_offerings/show.html.erb | archive | Preserve archive semantics, not hard delete |
| app/views/owner_ai_assistant/show.html.erb | paid | Preserve full localized consent and exact submitter name=paid_consent value=1; no request on cancel; do not default to consent |

## Turbo integration
Inspect installed Turbo API and its form submission confirm callback before choosing adapter registration. Prefer supported asynchronous confirm hook over manual submit replay. Identify kind from explicit allowlisted data attributes on form or submitter, preserve original message, form, CSRF, method, submitter and fingerprint. Fail closed on ambiguity. Do not globally intercept unrelated forms or remove server-side consent/authorization/idempotency. A second click while confirmation is pending must not initiate another mutation.

## Staged implementation / acceptance
1. Shared request lifecycle and contextual discard compatibility, with synthetic system tests for safe default, cancel, Escape, duplicate requests, teardown and stale frame. Existing contextual tests stay valid.
2. Quiz navigation and both invitation overwrite sites; test retain/replace, stale source, no network, share-checkbox behavior and native unload preservation.
3. Six Turbo sites, explicit per-site semantics; test cancel zero writes, approved exactly one intended request in isolated synthetic DB; verify preserved submitter and fingerprints. Paid AI is last, mocked provider only: zero calls on cancel, existing server consent checks intact, no actual provider spend.
4. Exact code SHA CI + security + Chrome system suite, followed by guarded local review :3003; desktop, 390/320 px, keyboard, long messages, scroll, iframe and focus. No production deployment or real DB/AI actions. Record evidence separately in execution status. Do not mark F2.5 complete until all gates pass.
