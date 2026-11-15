# RC055.1d — Catalogue Copilot, owner avatar, UI preview (2026-11-16)

Parent PR #68 (RC055.1c), stacked Draft. No production changes. Approved White Atlas styling is mandatory, see docs/WHITE_ATLAS_UI_CONTRACT_2026-11-15.md.

## Goal
- Owner requests a configurable AI copilot to reduce repetitive manual content review across the app.
- This slice implements the first reusable workflow: catalogue-wide textual quality review. It is NOT full system-wide autonomous agent capability; later slices apply this to profile, intakes, specifications, file analysis and client spaces.
- New owner-only /workspace/services/ai shows consent/price, the last AI suggestions, side-by-side original/proposed categories and texts, rationale/risks and Apply to draft per offering.
- No provider call on GET, navigation, login or background jobs. A POST requires explicit paid_consent=1. Calls use existing OwnerIntelligence::Grok configuration and AiSpendLedger budget, quotas and deduplication; a result is retained as ledger evidence. One bounded catalogue call (up to 12 offers, 22KB input), no attached bytes, KYC, contacts, credentials, private profile or keys.
- Grok cannot execute code, browse, use tools, edit data, approve or publish services. Suggestions are schema-validated and bound to exact digest/version/snapshot. Owner applies into a draft or creates a new draft for an approved service, leaving approved/published pointers unchanged. Stale and foreign data fail closed. Owner separately finalizes/enables.
## UI
- Owner cabinet Catalogue AI assistant, AI review links on catalogue and detail.
- Unapproved owner-private banners preview on owner-only cards with explicit badge, approved cover preferred. External client and public routes unchanged.
- Owner avatar upload (local loopback and tests only), append-only revisions, owner-scoped protected file URL, never public blob route.
- Native file input upgraded to White Atlas mint outlined area with browser picker, focus and responsive.
## QA
- RC055.1c backup+restore confirmed 2026-11-15. No new DB migration in this branch. SQL backups do not contain avatar and media bytes, so protect storage alongside DB.
- Rails/Chrome/Security CI on final SHA, owner browser screenshots. No AI requests executed during CI.
- To actually invoke paid Grok, owner must confirm environment RC_GROK_ENABLED and budget, then explicitly tick consent. Real billing may occur. Check /workspace/ai ledger.
- Client/guest/foreign owner cannot access reviews or private avatars.
## Roadmap
- RC055.1e: general page-level AI action registry, privacy and prompt policy, versioned suggestions and owner approval.
- RC055.2: client catalogue, service picker, Other fallback.
- RC056 manual+Grok qualification, RC057 proposal, RC058 project workspace/files/calendar, RC059 release/object storage/backup gates.
No changes to main or Railway; parent PRs stay Draft.
