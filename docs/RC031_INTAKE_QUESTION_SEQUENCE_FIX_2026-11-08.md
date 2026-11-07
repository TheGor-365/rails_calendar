# RC-031 — fallback intake question sequencing

Parent: RC-029 integrated draft / [PR #30](https://github.com/TheGor-365/rails_calendar/pull/30). Reported from an owner's screenshot of **production-deployed, private synthetic intake #1** on 2026-11-08.

Bug: the seeded opening question asks about audience and primary action, then the first answer generated fallback `QUESTIONS[0]` — the audience topic repeated. This was an off-by-one error in `Intake::Grok#interview_question` (`client_message_count - 1`). It only affected new offline/template questions; it did **not** delete recorded answers or modify another intake.

Fix:
- After client answer N, choose `QUESTIONS[N]` (starting from pages/features when N=1).
- On the eighth answer, persist a clear final assistant message and stop asking; do not trigger an unnecessary billable Grok call. The form remains closed by the existing eight-answer cap.
- Existing replies and answers are immutable, including intake #1's redundant question. User need not repeat the same answer.

Regression: exact second question, all eight distinct topic progressions, final message, no ninth answer or AI quota usage; tests only use fictional fixtures.

No migration, schema change, customer account, role/ACL alteration or third-party API request. Keep `RC_GROK_ENABLED=false`, `RC_INTAKE_PUBLIC_DEMO=false`, `RAILS_CALENDAR_PUBLIC_DEMO_MODE=false`. Deploy a pinned SHA only after CI and Security pass; no new Railway service or DB.
