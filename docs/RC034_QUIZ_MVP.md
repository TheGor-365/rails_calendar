# RC-034 — owner-only offline Quiz MVP

Base: RC-032 SHA `96419a2a9dab53e6fa9b62593b52e323cdfbacb5`.
New branch: `feat/rc034-quiz-mvp-2026-11-09`.

First vertical slice:
- Two deterministic cards per existing project type: primary outcome (single select) and features/problems (multi select).
- Supports user-written alternative, Not sure, optional comment, back/edit and review.
- Persists `IntakeAnswer` JSONB selections, plus append-only `IntakeAnswerRevision` snapshots.
- Changes serialised with project intake row lock; same inputs do not generate duplicate revisions.
- No Grok calls, no new public registration, no client-facing ACL; legacy interview remains available.
- Owner session only; legacy administrator login cannot access the quiz. Use fictional data, local isolated DB and tests.

Acceptance gates: isolated dev/test DB identities checked, migration succeeds, controller/system tests green, local browser smoke, then separate Draft PR stacked on RC-032. No Railway deploy without explicit release gate.
