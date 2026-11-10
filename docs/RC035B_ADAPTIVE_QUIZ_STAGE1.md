# RC-035B — Adaptive Quiz, stage 1 (Draft)

This is a **non-production, no-database-change** foundation. It is stacked on the exact
RC-035 SHA 8c4a29c2f002c64d9b771df5f9eb2bb80416a399. It must not be
released to Railway or merged to main before the production-owner and QA gates.

## Delivered

- \`Intake::AdaptiveQuestionCatalog::VERSION = "rc035b.v1"\`.
- Section A is the existing \`ProjectIntake#project_type\` selection.
- Declarative, offline sections B–G for the four currently supported project types.
- B: business goals; C: audiences; D: scope and specialized questions;
  E: website/redesign materials only; F: integrations; G: constraints.
- Section H will remain a *private draft review* until client ownership/ACL is complete.
- \`Intake::BranchingEngine\`: conditional questions appear only after qualifying
  answers, including website checkout and API webhook recovery.
- A generic \`unknown\` fallback is available in the catalog, but is **not**
  yet a persisted \`ProjectIntake\` type.
- Unit tests exercise specialization, fallback, key uniqueness and branch visibility.

## Explicitly NOT delivered

- No routes, UI integration, migrations, public Submit, new project types,
  answer persistence, priority selection, branch invalidation, or AI usage.
- Existing \`Intake::QuizCatalog\` and its two-question RC-034 flow remain unchanged.
- No production owner has been created by this commit.
- No Railway configuration or deployment changed.

## Next stages

1. Complete RC-035 one-time private owner bootstrap and verify protected login.
2. Integrate a versioned catalog into owner-only Quiz, with server validation,
   snapshots, explicit branch invalidation and preserve/change notices.
3. Add priorities \`must/should/later\`, remaining project types, UX and full
   test coverage, then seek a separate production release decision.

## Evidence

- Stage-1 catalog/branching classes: pure Ruby syntax and offline smoke
  checked by the assistant (Ruby 3.3.8 tool container, **not** project's Ruby 3.4.12).
- GitHub CI and Security Audit on the eventual PR head SHA are the authoritative
  checks; do not mark these as passing until observed.
