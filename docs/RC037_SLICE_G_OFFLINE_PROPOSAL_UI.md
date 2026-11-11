# RC-037 Slice G — explicit offline proposal UI (owner-only, zero-cost)

**Not for real clients or production.** Adds a form to the *existing* `Studio::AiSettingsController` and Settings page; no new app or duplicate dashboard. POST `/workspaces/:workspace_id/project_intakes/:id/offline_proposal` runs only after an explicit button press. In Rails production the route returns 404. Development requires explicit `RC_STUDIO_AI_OFFLINE=true`; Rails test is permitted.

The controller uses existing authenticated owner/workspace/intake checks and the Slice F audit-verified zero-cost admission, followed by scoped `OfflineSourceSelector` and exact `OfflineOutputContract`. Source selection is optional, bounded <=10 and strictly numeric; UI displays ONLY state `metadata_only` sources matching the current client/intake. No raw bytes, filenames, private keys, object URLs or client documents are fetched. Values for `provider`, `estimated_usd` and secret-like parameters are not used.

Only fixed synthetic safe text is displayed, HTML-escaped, marked **needs human review / unverified**. Preview is not persisted as a document, does not approve anything, does not create a policy revision, does not charge tokens or invoke an LLM. Invalid/missing policy, cross-client ID, revoked owner, forged selection or broken audit all fail closed and display a generic 422.

HTTP tests cover guest/tenant/revoked/production denial, explicitly allowed preview, no mutation/cost/source body leak, hostile params and corrupted audit. Manual browser/mobile 320/390/430px acceptance and accessibility QA remain outstanding. No external AI or production access.
