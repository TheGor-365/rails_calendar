# RC055.0d — Current now / conversation history (2026-11-15)

## Decision
Based on owner/client screenshot QA: long duplicated client goals, minimal role contrast and chronologically mixed messages bury the actionable state. Introduce clear progressive disclosure without converting speculative AI data into canonical facts.

The detail is divided into (1) **current stored snapshot**, (2) compact request state/latest version, (3) expandable original goal, (4) history with role/search/chronological filters, (5) owner/manual next action and scope sections. The current stored client turn is full text and always visible to the authorized owner, so advancing `OwnerIntakeReadState` to that displayed ID does not mark a hidden turn as seen. The history window is **the most recent 20 records**, sorted chronologically by default; older records remain in PostgreSQL but are not falsely advertised as browsable. Server-side pagination/complete history is a distinct future task.

Client view only receives the `published_spec`, never private draft. Owner sees `latest_spec` with explicit draft/approved classification; a read receipt is NOT approval or contract acceptance. Human or AI provenance can be asserted only when stored explicitly. Existing `IntakeMessage.role = client/assistant` does **not** distinguish template from paid Grok, and the UI must not invent it. An owner clicking the old legacy demo `reply_project_intake` on a verified-client request previously created a *client-role* message and invoked the demo question workflow; now server rejects it with 403 and the misleading form is hidden for client-associated intakes. Authentic owner/client exchange will get a dedicated versioned author/channel contract in RC056, not a disguised legacy route.

## Future strict+flexible content shape (not migrated here)
- Envelope immutable: `record_id, intake_id, sequence, entity_kind, actor_type, actor_id, origin (client/human/template/ai), source_version/digest, visibility, created_at, review_state, superseded_by, parent_id`.
- Flexible payload by typed JSON schema: `message.body`, `fact.value/evidence_refs`, `question.prompt/answer`, `spec.section`, `proposal.terms`, `file_version.checksum`. Strict metadata, schema-validated flexible body.
- Read projections / latest materialized state derived from approved facts and saved messages. Do not mutate historical meaning or promote AI suggestions to facts. Source/approval/digest must be explicit.
- Event history is never a single unbounded HTML dump; pagination, date/role/type/source/version filters, full-text search and provenance timeline are future planned increments.
- Avoid auto AI calls, pricing claims, production data, schema changes, new JS dependencies or global visual redesign.

## Acceptance
1. Current owner/client record shows the actual latest client message and correct persisted spec state. Newest message remains visible while history is collapsed; read cursor advances only to displayed latest id.
2. Long original brief and multi-message history can be expanded; original text preserved and escaped; mobile 320/390 no horizontal overflow.
3. Client-owned request cannot use old synthetic `project_intakes/:id/reply` route even as an owner; legacy owner-created demo remains usable; no call to paid model.
4. Both owner and client have search, author filters, chronology; preserve locale RU/EN/HY/ES; no historical data changed.
5. Automated Rails, Chrome and Security PASS exact SHA; local visual owner acceptance still required. Draft stacked on #62; no Railway/main changes.
