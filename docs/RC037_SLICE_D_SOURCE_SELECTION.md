# RC-037 Slice D — explicit, tenant-safe source metadata selection

**Stacked Draft PR #37**, no prod deployment. `Studio::OfflineSourceSelector` handles a bounded explicit list of 0–10 numeric source IDs, enforces original owner membership at initialization **and** every selection, exact workspace/intake/client plus metadata-only state, and rejects any missing/foreign/duplicate IDs rather than silently mixing contexts. It returns only ID, SHA256, format and byte count — never filename, body text, object key, token, URL or private segment.

`Studio::OfflineAiDispatcher#call(..., source_ids: [])` now requires explicit source selection for the count in its validated response; the default is zero. It cannot infer consent from a source, ask external AI, or automatically approve any document. Cross-client/foreign tenant selections fail closed.

Tests verify empty/default, bounded shape, same-workspace different client, foreign workspace, revoked owner, forged IDs, no source bytes in output, and zero provider/billing calls.

This is an **offline metadata-only ACL gate**, not authorized retrieval of document contents, normalization, embeddings, client answers or RAG. Consent, AV clearance, encrypted durable blob storage and request-time access checks remain distinct release blockers.
