# AI Service Workspace — context intelligence contract (RC-035B/RC-036/RC-037)

Status: **owner-only/offline foundation**, 2026-11-10. No real customer memory, no xAI call.
Source roadmap: \`RAILS_CALENDAR_AI_WORKSPACE_ROADMAP_RC035_RC042_2026-11-10.md\`.

## Objective and product UX

Make every AI clarification accurate and economically justified while the interface remains
a fast one-question-at-a-time White Atlas flow. Inputs: service, confirmed/pending
requirements, audience and constraints, technical feasibility, revision history and
approved decisions. Outputs: at most 3 sourced clarifying questions, an honest
list of remaining unknowns, or **no question**. Human review always controls scope.

Never achieve "full context" by dumping all chats into every prompt. Full history
is an access-controlled archive; each inference receives the minimum relevant
subset plus exact provenance and pointers for targeted follow-up.

## Data trust hierarchy

1. **Verified system facts** — application repository stack and checked deployment
   settings. These do not independently prove the master's proficiency.
2. **Master capability profile** — versioned, reviewed owner-curated taxonomy
   \`config/ai_workspace/master_profile.yml\`; service slices, constraints, cautious
   phrasing, delivery/acceptance standards. Missing evidence is \`needs_validation\`.
3. **Respondent-reported facts** — \`ProjectIntake\` title/goal, current
   \`IntakeAnswer\` selections/text/priority, with source id and revision.
   These are NOT signed scope or independently verified client identity.
4. **Historical facts** — immutable \`IntakeAnswerRevision\` snapshots, legacy
   \`IntakeMessage\` chronology, \`IntakeSpecVersion\` index, including inactive
   branches. Read exact history on demand; do not present old inactive answers
   as current requirements.
5. **AI suggestions** — never written into respondent facts or approved
   specifications automatically. Maintain \`suggested\` status until human
   acceptance and record a source/version.

Do not place actual master identity, phone/email, bank details, payment data,
client PII, documents, secrets or private notes in the public GitHub profile.

## Implemented now

- \`Intake::Intelligence::MasterProfile\`: typed, validated, revisioned safe YAML.
- \`ContextAssembler.new(intake:, actor:)\`: persisted \`owner\` actor required;
  scoped answers, current visible branch, per-answer priorities, source refs,
  selective section ranking by task, no external payload method.
- \`ContextAssembler#history_for(question_key:)\`: exact immutable revision
  snapshots for the same intake. \`#conversation_for\` and \`#spec_for\`
  support owner-only drill-down. Summaries/indices contain references, not full
  transcript dumps.
- \`ClarificationPlanner\`: catalog-aware deterministic gap ranking, prioritizing
  relevant requirements, maximum 3 unanswered/unsure items. No model billing.
- \`PromptContract\`: system instructions and restrictive JSON output contract
  for future xAI adapter; no live provider connection.
- RC-035B v2: persisted \`feature_priorities\` (must/should/later) per selected
  feature; new locale, data category and existing-assets questions. Existing
  v1 snapshots remain in history unchanged. Legacy two-question Quiz is intact.

## Future customer dossier (RC-036: **not yet stored**)

Use \`Workspace\`, \`Client\`, \`ClientFact\`, \`ClientFactVersion\`,
\`KnowledgeArtifact\`, \`Consent\`, \`AiRequest\`/ \`AiCall\` (names may be revised
at schema review). Every retained fact should carry:

- \`workspace_id\`, \`client_id\`, \`intake_id\` or bounded aggregate scope;
- \`field_key\`, typed value, locale and source reference;
- \`status\`: reported, verified, suggested, disputed, unknown or excluded;
- \`recorded_at\`, last confirmed, supersedes, expiry/retention policy;
- consent/purpose, sensitivity category, allowed audiences, deletion policy.

Collect only data needed for delivery: product/business goal, stakeholders,
audiences/markets/languages, current stack/version/hosting, existing features,
reproduction and constraints, integrations and data categories, accessibility,
volume, design/content ownership, budgets/timeframe *as preferences*,
scope exclusions, communication channel and decision history. Never request
secrets, ID scans, payment credentials, or unsupported inferences.

**No cross-client search, embeddings or global customer memory** until
workspace-scoped ACL, consent and deletion tests pass. An owner role alone
is NOT a substitute for future client isolation.

## Request algorithm / token efficiency

1. **Authorize:** check user, workspace/client ownership, operation, consent,
   sensitivity and provider eligibility. Fail closed.
2. **Classify the task:** clarification, estimate, spec, bug triage, API,
   change impact. Apply the matching service capability profile.
3. **Build current fact graph:** IDs/revisions, statuses, active branch,
   exact requirement priorities, constraints. Detect contradictions and
   stale/inactive items; never silently overwrite original records.
4. **Ask deterministic questions first** when the catalog already covers a
   high-impact gap. Prefer zero API calls over generic AI prose.
5. **Retrieve on demand:** review only specific revised answers, conversations
   or specs relevant to a contradiction; never dump every conversation.
6. **Construct bounded provider candidate:** lock system contract,
   compact structured facts with source refs, a max-question count and
   max token budget. Deduplicate repeated fact text. Tag truncation and
   missing evidence explicitly. Current \`char_budget\` bounds *answer facts
   only*, not the entire internal owner packet; exact token accounting will
   belong to the provider adapter, and the current \`estimated_fact_tokens\`
   is only an approximation.
7. **Gate cost (RC-037):** provider disabled by default, per-request,
   project/day/month USD caps, reserve-before-call, idempotency key from
   scope+fact revisions+prompt version+model, retries/backoff and circuit breaker.
8. **Validate response:** strict JSON Schema, source refs must be real,
   options from an allowed taxonomy, no new arbitrary steps or HTML,
   no invented certainty/price/dates. Reject unsupported suggestions.
9. **Human approval:** show exactly the minimal proposed clarification,
   "Why we ask" and source. Store suggestion as \`suggested\`, record
   acceptance/rejection and re-evaluate when underlying facts change.

Cache only with an auditable signature and privacy-aware retention.
Do not conflate reduced prompt characters with measured provider tokens/cost.

## Security and release gates

- Current \`ContextAssembler#provider_payload\` deliberately raises
  \`SecurityError\`. No customer data sent to Grok, no public user endpoints.
- Add RC-036 ACL/consent/retention before any real customer dossier.
- Add RC-037 exact model/pricing verification, schema validation, tested
  provider adapter, budgets and spent-token accounting before any paid call.
- Prompt-injection tests: malicious respondent comments, long documents,
  counterfeit system messages, cross-client identifiers, secret-like tokens,
  fabricated price/SLA. Fall back to deterministic questions and mark failures.
- Never treat an AI-proposed deadline or scope as an agreement. Separate
  human acceptance of scope, price and timeline in RC-038.

## Definition of Done for this foundation

- CI/security green on exact HEAD; deterministic owner scoped context and
  targeted histories with cross-intake negative tests.
- Selected priorities are persisted and appear in exact revision snapshots;
  malformed/foreign priority keys rejected, existing legacy Quiz unbroken.
- No cross-project history, no external provider calls, no production mutation.
- Simple mobile form; browser flow at 320/390/430 px and keyboard still passes.
- RC-035B stays Draft until a separate production release/backup approval.
