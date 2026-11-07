# RC-029 integrated human-reviewed specifications + private milestone calendar

Parent: RC-028 milestone timeline [PR #28](https://github.com/TheGor-365/rails_calendar/pull/28), integration of human-review code from [PR #29](https://github.com/TheGor-365/rails_calendar/pull/29). Draft, no merge/deploy.

Demo workflow: fictional request → Grok/template interview → generated draft spec → **admin edits and saves a new human-authored version** → explicit admin approval → client sees last published version → owner creates milestone schedule (working days, weekends skipped) tied to approved version → private calendar visible only in that same demo browser session or to admin.

Rules: editing never mutates prior versions; earlier published version stays visible while newer draft is prepared; client acknowledgement does not override a newer draft state; milestones remain tentative and immutable after creation. No client accounts, contracts, payments, active progress tracking, real customer data or direct changes to `consultations`. Same-browser demo ownership is NOT secure multi-device identity, and public real-client launch remains blocked.

QA: run Rails CI + security audit on exact integration SHA; ensure old milestone and new human-revision tests pass; manually review UI only on synthetic staging. Separate Railway deployment, TLS/proxy validation, xAI credential setup and cost caps still outstanding.