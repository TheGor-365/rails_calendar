# RC-039 Slice C — HTTP admission for fictional Project Hub cards

**Test-only JSON prototype — no owner UI or public routes.** Adds three narrowly scoped routes *inside \`if Rails.env.test?\`* for \`GET project_hub\`, \`POST project_hub/cards\`, and \`PATCH project_hub/cards/:card_id\`. These routes do not exist in development or production; the controller also hard-denies either environment. No Turbo/HTML client interface, no arbitrary task parameters, no document generation, no external AI, no invoices/exports or real customer files.

\`Studio::SyntheticProjectCardsController\` uses the existing revocable DB owner session, active workspace owner membership, client/intake scoped lookup and Slice B's service. The read endpoint returns only Slice A's closed nine-card catalog plus fixed metadata-only saved card receipts. The write endpoints permit a fixed \`artifact_key\` and an exact expected state/version transition into Slice B's three nonapproval states. All other parameters — including claimed approval, hidden source content, customer identities, spending and assignments — are ignored. Unauthorized tenants or inaccessible cards return 404; invalid synthetic operation returns 422, version conflict 409. Unknown or revoked owner cannot read or mutate. A missing owner session redirects to the existing sign-in form.

Private cache/no-referrer/nosniff response headers apply; mutation keeps Rails' standard cookie-bound CSRF protection and same-origin verifier (explicitly exercised in integration tests by enabling forgery protection). There is no permission for direct Active Storage URL, client API, production task creation, or even a public development demo. The client calendar and consultation calendar are untouched.

### Acceptance

- Run only in disposable, isolated \`ruby_calendar_test\`; migrations from Slice B are already in that test DB.
- \`bin/rails test test/controllers/studio/synthetic_project_cards_http_test.rb\`, followed by full Rails suite.
- Exact-head push/PR CI + Security Audit; manually inspect the JSON protocol before enabling a future UI. No live client data.
- Preserve any locally changed \`db/schema.rb\` in isolated QA worktrees. No merges or deployments.
