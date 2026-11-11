# RC-038 Slice A — synthetic source normalization and provenance graph

Status: stacked Draft branch off RC-037. Not a released feature; no migration, HTTP route, provider or deployment.

Goal: deterministic untrusted source segments and candidate facts for synthetic MD/TXT/JSON without persisting document bytes.

- Requires active owner access and exact workspace/client/intake/ProjectSource metadata scope, source fingerprint, parser format and byte length. Quarantined source bytes cannot bypass scanner.
- Explicit synthetic confirmation plus test environment or local development opt-in; hard production deny.
- Segments use line locators for Markdown/TXT and escaped JSON pointers for scalar leaves, SHA256 source/text hashes and deterministic IDs. Fenced Markdown code is excluded; duplicate JSON keys rejected.
- Graph edges represent reported-in relationships, not client approval; statuses only reported or unknown. No automatic verified status, prices, scope, client consent or deadlines.
- Output is bounded at 40 segments and 240 characters per segment, 180-character locators. Truncated and omitted entries cause partial coverage, with no fact candidate for truncated text.
- Immutable metadata-only ProjectSource remains unchanged. No ClientFact writes. Output explicitly declares stored=false, provider_ready=false, auto_approved=false, zero external calls and billable spend.

Acceptance: tests for deterministic graph, stable line/JSON provenance, duplicate key rejection, mismatched digest, cross-client/foreign tenant, revoked owner, production block, adversarial fenced content, truncation and no persistence.

Unverified: encrypted durable source segments, real client consent, official antivirus signatures, DB + blob backup and restore, dispute resolution, independent audit anchor, actual document generation and production release.

Next: exact HEAD GitHub CI and Security Audit, then synthetic-only reconciliation preview in RC-038 Slice B. Keep production and real client documents disabled.