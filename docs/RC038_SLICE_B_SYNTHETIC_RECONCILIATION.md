# RC-038 Slice B — ephemeral comparison of two synthetic source graphs

**State:** implemented in stacked Draft PR #38, subject to exact-HEAD CI and manual local acceptance. No production deployment, external AI, source persistence or real client documents.

## Scope

The owner-only service \`Studio::SyntheticSourceReconciliation\` accepts two exact source descriptors (\`source_id\`, \`filename\`, \`bytes\`) plus a scoped workspace/client/intake and \`explicit_synthetic: true\`. Each input must pass the existing Slice A \`SyntheticSourceNormalizer\`: owner and tenant ACL, metadata-only source record, SHA256/size/format/parser match, quarantine block and test/explicit local-dev gate. There is no new HTTP route and no database migration.

For each incoming unverified fact candidate it returns one of:

- \`corroborates\`: exact normalized value and type matched a previous claim; **not verified**, approved or a substitute for client confirmation.
- \`conflicts\`: differing claim of the same type at the same source locator with complete available coverage; human investigation required.
- \`new\`: not observed in a complete baseline; not a verified new requirement.
- \`unknown\`: null, previous unknown, changed type or incomplete evidence. Incomplete baseline never licenses an absence claim.

The comparison uses exact claim identity (only whitespace normalized) and consumes baseline matches to avoid reusing one claim for multiple incoming duplicates. Locator changes are not silently treated as supersession. The report includes deterministic fingerprint, source IDs, aggregate counts and references to candidate IDs/line locators; it **does not copy source text** into the comparison output. Missing baseline claims are counted only, never deleted or automatically superseded. All statuses are proposals with mandatory human review; costs and external calls are zero.

## Proof and exclusions

Automated tests cover exact reuse/determinism, JSON pointer conflict/new/unknown, missing baseline on partial evidence, inexact Markdown replacement, wrong client/tenant, revoked owner, production gate and no writes. SQL/DB owner gating is inherited from the normalizer/registry. The service must not be used on real client files until proper encrypted private storage, updated ClamAV signatures, legal consent and human-reviewed ACL/backup-and-restore gates exist.

Next: additional conflict specificity (key/section anchors beyond line numbers), owner review UX and durable immutable fact/revision model only **after** privacy safeguards. No silent acceptance of AI/source instructions.
