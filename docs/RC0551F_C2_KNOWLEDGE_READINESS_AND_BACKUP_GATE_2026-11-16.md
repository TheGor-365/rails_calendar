# RC055.1f C2.0 — Owner AI knowledge coverage & consented source contract

Date: 2026-11-16 · Parent: [Draft PR #73](https://github.com/TheGor-365/rails_calendar/pull/73) HEAD `0e5de61796f3f685ca84f8ab7288e106a1341a6e`. **This C2.0 branch is Draft only, not approved for production.** No migration, data changes, new API permissions, AI provider charges or automatic publication.

## Evidence and defect addressed
- Owner's local git output confirms branch #73, HEAD `0e5de61`, `bundle check`, `yarn build`, `yarn build:css`, `bin/rails restart`, clean working tree. No owner screenshot/visual signoff for C1 yet.
- Code inspection: `OwnerIntelligence::Compiler.build` serializes the approved snapshot's shareable public summary into `payload["public_summary_draft"]` (it remains **unpublished**); `OwnerAi::Composer` previously selected `payload["public_summary"]` only. Therefore, approved shareable narrative may have been silently absent from Grok input. C2.0 maps the approved snapshot's `public_summary_draft` to the stable provider-facing `public_summary` key, with legacy fallback. Explicit per-call paid consent is unchanged; owner private summary, raw interview responses, client messages, files, hidden service scope and account secrets remain excluded. **This is a payload change to future consented calls; do not claim prior runs included this text.**
- `OwnerAi::KnowledgeReadiness` makes truthful source states visible on owner `/workspace/assistant`: approved profile public facts available by consent, number of private/approved offerings (NOT automatically passed), FAQ and pricing knowledge not yet structured, document ingestion not connected. No misleading readiness percentage, no copy of private content to page or client.
- White Atlas scoped 2-column/1-column 320px cards; RU/EN/HY/ES; owner/client and source-provenance integration tests, existing Chrome responsive coverage.

## Data-trust matrix (mandatory for C2/C3)
| Source | Exists | Current Composer sends | Client consultant permitted? |
|---|---|---|---|
| Approved profile headline | On signed-in owner's approved snapshot | Yes, only after owner checked consent | **Not yet:** separate publication + data policy required |
| Approved shareable public-summary text (`public_summary_draft`) | Owner-approved snapshot; NOT publicly published | Yes after C2.0 patch + consent | Not before explicit client-facing publication |
| Private summary, full interview, hard-no-go policy | Private snapshot/profile | **No** | No raw release; evaluate deterministic policy privately |
| Owner ServiceOffering versions/media | Private owner DB/files | **No** automatically | Only selected approved+explicitly published version after RC055.2 gate |
| Client ProjectIntake messages/PII | Private role-protected records | **No** | Own client request only after scoped consent and redaction |
| Owner FAQ/prices & business terms | No structured owner-approved source yet | **No** | RC055.1f C3 verified knowledge capture |
| Uploaded documents | Private storage may exist | **No** read/send | C3/RC056 scan, parse, classify, consent, retention and download ACL |
| Signed contract/payment status | Not implemented | **No** | RC057/059 after legal + verified payment gate |

## C2 persistent conversation blocker / release gate
Build durable conversation entities ONLY after owner-private backups:
1. Verify current branch SHA, preview database name `rails_calendar_mvp_preview_20261112` and user `gor`, local Postgres CLI 16, and Active Storage private disk path. **Never print credentials**, `.env`, secrets or private originals.
2. Make new restrictive-permission, timestamped PG custom archive (no overwrite of 2026-11-15 backup); also archive private `storage/` bytes to an owner-only directory outside Git and the project. Record checksums, tables/versions/counts.
3. Verify `pg_restore --list` and an isolated scratch-database restore; verify private file/attachment correspondence. **Do not touch the existing preview DB until restore confirmed; do not run production migrations**.
4. Only then implement `AiConversation`, `AiConversationTurn`, `AiActionRun`, `AiActionSuggestion` or equivalent versioned schema; source labels, owner/client actor, immutable snapshots/digests, 429/timeout uncertain billing and explicit per-turn consent. Test race, cross-account ACL, prompt injection and retention.

## Next roadmap
- C2.1: approved per-conversation source selection and typed tool permission service; persistent user+AI turn ledger behind verified backup and migrations; coherent modal/mobile chat with Esc/focus/scroll.
- C2.2: safe `read -> propose -> compare -> confirm -> apply -> undo` on versioned private service drafts; no generic execute tool.
- C3: professional FAQ/prices interview, owner-approved knowledge releases and sanitized document ingestion, no KYC/credentials.
- RC055.2 client published catalogue + invitation and client advisor; RC056 adaptive questionnaire/files/spec package; RC057 scope/quote bilateral revisions and legally reviewed signatures; RC058 calendar/task execution; RC059 release gates. Do not change sequence.
