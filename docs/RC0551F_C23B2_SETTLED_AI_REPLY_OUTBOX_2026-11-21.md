# Rails Calendar — C2.3b2: settled AI reply → durable outbox → owner sources
Date: 2026-11-21. Status: code added to stacked Draft PR #81; exact-head CI required.

## Source contract and staged behavior
- Owner AI requests pass through `OwnerAi::ConversationResponder`; a paid attempt is accounted for by a separate `AiSpendEntry`. No outbox event is created on draft, pending, uncertain or failed assistant turns.
- When an authorized `OwnerAiMessage` belonging to the owner workspace first becomes `assistant/settled` and has a *settled* ledger, an `after_save` callback enqueues a private `DomainOutboxEvent` in the **same database transaction** as the saved reply. New source mapping: `OwnerAiMessage / ai_reply_saved`, source_version = immutable sequence in the conversation. No answer text or prompt is stored in the outbox.
- An existing-format `ActivityEvent` is created after commit for immediate UI. Its key is `OwnerAiMessage:<id>:ai_reply_saved`, and the event has a generic title, no full message body. Existing `AiSpendEntry/ai_settled` continues to document the separate accounting event.
- A bounded manual `DomainOutbox::Replayer.run!(workspace:, limit:)` accepts only allowlisted source pairs. For an AI reply it checks the persisted assistant message, saved state, conversation workspace, source sequence and a settled ledger owned by the same workspace, then recreates a missing `ActivityEvent` with the same deduplicated key. The original source remains the saved message; replay never invokes Grok/another provider, creates invoices or updates ledger.
- `Activity::Presenter` links this event to the exact owner conversation when still authorized, else to the owner's conversation list. The activity timeline and month/day/hour calendar use this event projection; the existing library already resolves settled AI spending records to the saved owner conversation via `Activity::SourceLinks`. No duplicate library record or client access is introduced.

## Test contract
- A pending assistant message is **not** queued.
- First transition to settled generates exactly one outbox envelope and one owner activity event, storing no response body in event metadata.
- Re-editing a settled reply's body does not issue an additional event in this first slice; a future immutable content revision model would be required to track post-settlement edits.
- Missing activity replay recreates exactly one event without new `AiSpendEntry` or `OwnerAiMessage`; repeat replay has no changes.
- No cross-workspace replay or direct event injection. Missing or invalid source is not rendered as external arbitrary URL.
- If the source transaction rolls back after transitioning to settled, its outbox insert rolls back too.
- Rails, Chrome, PostgreSQL 18 clean migration and upgrade-from-deployed, and Security Audit must pass on the final **same SHA** before the slice is accepted. Human :3002 UI test remains a separate gate.

## Next
1. Confirm exact SHA CI/Security. Resolve test failures without widening production access or altering user DB.
2. Before applying any migration locally: verify exact database URL/name/socket, confirm read-only backup/restore preflight and a fresh dump to a separate safe location. Keep local modified `db/schema.rb` intact; never run `db:reset`, `db:prepare`, `db:migrate` or overwrite schema without separately checked procedure and user's action.
3. Only after safety and browser QA: add additional canonical source adapters (invitations, service versions, scope edits) individually, retaining human publish gates, then C2.3c projection metrics and C2.4 reviewed AI ActionProposal engine.
4. Long-term architecture: one consented model call → one settled source object/immutable revision → one durable outbox record → deterministic, authorization-aware calendar/library/activity/project/notification projections; no extra model costs for views.

## Boundary
Code exists only in a Draft feature branch. No code on main, original port 3001, local :3002 database or Railway production is changed by this slice. No external request, AI charge, scheduler, emails, client publication or customer data is involved.
