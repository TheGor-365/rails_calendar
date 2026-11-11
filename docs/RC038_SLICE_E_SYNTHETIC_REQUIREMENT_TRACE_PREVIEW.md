# RC-038 Slice E — read-only fictional requirement traceability preview

**Only Rails tests or explicitly opted-in local development.** This adds no public route, persisted requirement/fact/segment content, migrations, customer-data ingestion, AI provider call, document generator, export or production access.

\`Studio::SyntheticRequirementTracePreview\` validates the exact owner, workspace/client/intake and both synthetic sources through the existing reconciliation + Slice D readiness services. Readiness also validates the entire set of immutable Slice C owner-triage receipts. Every newly constructed trace references the incoming unverified fact candidate, its source segment and locator, the incoming source record, an optional exactly matching baseline claim and the owner decision receipt. Trace IDs are deterministic SHA256-derived opaque presentation identifiers, **not access tokens**.

Only candidates with an explicit \`retain_for_review\` decision and safe \`new\` or \`corroborates\` state become trace preview rows. \`unknown\`, \`conflicts\`, \`needs_information\` and \`exclude_from_draft\` never become retained requirement traces. Exclusion and incomplete review keep the separate \`eligible_for_unapproved_synthetic_outline_review\` false. Absence of a prior claim with incomplete coverage is never declared as an approved new requirement.

**All traces remain unverified proposals**. \`requirement_approved=false\`, \`client_confirmed=false\`, \`document_generation_allowed=false\`, \`persisted=false\`, \`external_calls=0\`, \`billable_usd=0\` on every call. No source text, comments, filenames, document content or private object keys are returned or persisted.

Run targeted tests against isolated localhost \`ruby_calendar_test\`: \`bin/rails test test/services/studio/synthetic_requirement_trace_preview_test.rb\`. Acceptance additionally requires exact-HEAD CI/Security and owner Linux Mint results, plus independent manual QA for any future UI.

**Release blockers unchanged:** encrypted durable storage, live official AV signature evidence, identity and consent policy, full backup and tested restore, secure cross-tenant E2E, and explicit owner approval before production or real customer files.
