# RC055.1f Slice B — safe owner AI refinement, navigation and service draft apply
**2026-11-16, provisional implementation in Draft PR #72.** Parent Draft PR #71 (RC055.1f Slice A). No production merge, paid provider call, database migration or new client exposure.

## Screenshots and owner feedback
Owner inspected `/workspace/assistant` desktop and mobile in Chromium. Desktop layout consistent with White Atlas. Mobile DevTools screenshot showed **408 px**, not the requested 390/320. The floating launcher overlaps the native assistant form near the bottom nav. Parent PR #71 therefore adds a compact circular mobile toggle and extra bottom scroll space under `body.wa-ai-enabled`; no global calendar CSS is changed. The owner has NOT yet visually accepted the 390/320 state.

## New scoped functionality
1. A previous settled owner-only `AiSpendEntry` can be used as bounded prior AI output to refine a new private draft. 4 turns maximum, explicit paid consent PER turn, existing strict structured schema, full ledger/quota and uncertain-billing rules, exact owner/profile/version/operation checks. Previous user prompt text is NOT stored; a timeline of generated responses is displayed with native escaped markup. This is **bounded iterative refinement**, NOT a fully persistent multi-role conversational agent.
2. A typed "open services", "открой кабинет", etc. command is routed deterministically to a fixed list of owner pages. No LLM billing, no client-supplied URL redirects, no arbitrary tool execution.
3. For `service_copy` only, the owner chooses an EXISTING editable private ServiceOffering draft, sees the original summary and AI proposal side by side, edits the exact replacement (25–1000 chars), checks an explicit factual-review confirmation and POSTs. The server scopes the owner, settled AI ledger, operation, approved snapshot version, current service draft version/digest, and preserves all other fields — especially excluded scope, delivery mode, title, category and approvals. It cannot create or approve a service or mutate a published/approved version. Stale digests reject.
4. White Atlas: reuse existing `--ws-*` tokens, surfaces, actions, `rc-select`; add scoped classes for conversation history and before/after grid with 320px single-column fallback. RU/EN/HY/ES. No redesigned calendar/cabinet/nav.
5. Tests: owner/client/foreign ACL, zero-cost GET/nav, allowlisted navigation, stale/forged/confirmation gates, schema/provider mocked next-turn and privacy payload, Chrome manual comparison/apply and 390/320 no overflow. Final exact-HEAD Rails+Chrome+Security must pass.

## Next slices / boundaries
- RC055.1f Slice C: full persistent assistant chat with per-turn provenance/private redacted document intake **only after storage/privacy gate**, service-specific AI actions and versioned apply/undo for more fields, contextual buttons on individual pages. Do not confuse changing a draft summary with generic authority to edit all data.
- RC055.2 client catalogue and scoped agent, two-sided invitations; RC056 secure document/quiz; RC057 bilateral spec/quote/schedule/signature; RC058 execution calendar; RC059 release gates.
- No automated send, publish, KYC, contract signature or contract enforcement. Paid Grok model and API key remain unchanged. Never trigger a new paid call merely for UI test.
- Owner local preview remains on an earlier checked-out PR #71 until owner explicitly fetches #72 after green CI; do not infer local switch from GitHub branch existence.

## Production / release gates
Draft #72 remains unmerged; no Railway deployment. Require exact-HEAD Rails+Chrome+Security success, local bundle/yarn build, owner screenshots at desktop 1440 and mobile 390/320, privacy/ACL/expense review. Later migrations require DB + Active Storage snapshot backup/restore and explicit owner approval.
