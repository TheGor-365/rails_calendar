# RC055.1f C2.1b — private conversation UI, first vertical slice
Date: 2026-11-17. Parent: Draft PR #78 at 617a376d87c251a9e29b8e088721f8807ad60809.

## Scope
- Owner-only, workspace-scoped conversation index and detail; active and archived lists sorted by updated_at.
- Optional title for new conversations, safe plain-text rendering, and saved owner notes with state=draft.
- Parent-row lock serializes message sequence allocation against archive; request UUID makes same-form retries idempotent. Archived threads are readable but block new messages.
- Standalone White Atlas view and entry from existing /workspace/assistant. Responsive layout with a keyboard-accessible conversation drawer; no new JavaScript dependency.
- RU/EN/HY/ES copy states explicitly that texts persist privately in the database. No encryption, retention, or deletion guarantee is claimed.
- No model call, AI text synthesis, AiSpendEntry, client access, automatic application, publication, new DB migration, production deployment or existing preview-DB modification.

## Architectural decision
Reuse C2.1a OwnerAiConversation/OwnerAiMessage and existing AccountAuthentication. Keep paid draft generator and AiSpendEntry-based history unchanged. Separate controller avoids coupling storage with the paid Composer lifecycle. Only owner messages may be saved in this slice; later C2.1c controls paid assistant responses and ledger linkage.

## Verification and open gates
- This branch is stacked on PR #78; do not merge it into main by itself.
- Check exact HEAD Rails/model/controller CI, Chrome tests, security audit; later test 320px/390px/1440px and keyboard with local browser screenshots.
- Live PostgreSQL preview rails_calendar_mvp_preview_20261112 has NOT been migrated. Do not run db:prepare, db:reset, db:schema:load or this migration there without explicit owner approval and separately verified backup/rollback.
- Concurrent request errors and CSRF rely on Rails transaction + built-in form protection; test real concurrent scenario and CSRF in a dedicated follow-up before declaring complete acceptance.
- Do not expose owner texts in logs, GitHub issue comments or public documentation; avoid private content in screenshots.
- Next refinement: visual QA, failure-state review, accessibility and test coverage, then user acceptance. C2.1c paid AI adapter remains a separate gated stage.
