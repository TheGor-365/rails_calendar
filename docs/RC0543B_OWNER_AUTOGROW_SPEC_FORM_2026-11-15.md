# RC054.3b — Owner forms auto-grow, manual spec form contract
Date: 2026-11-15. Exact base `2701aa339857663a13b12bd03278f93e4d93e5aa`. Draft only; no merge or Railway changes.

## Delivery
- Opt-in, native `wa-autogrow` on existing owner-only demo intake new, reply box, editable spec sections, onboarding notes, professional summary, consultation description and reschedule reason.
- All fields preserve form names/ids, server max lengths, old values, native validation and existing Turbo/session behavior. No global CSS rewrite or model/DB/ACL/AI changes.
- **Functional form fix:** `admin/project_intakes/edit_spec` now explicitly declares `scope: :review`; its controller already requires `params.require(:review)`. Existing tests previously posted `review` directly and did not verify rendered HTML names. Regression now asserts field names and contract.
- One deterministic owner browser system test verifies textarea input growth and no mobile overflow at 320/390.

## Gates
Exact head Rails/Chrome/Security PASS; local JS/CSS; owner UI screenshots and manual form submission + stale conflict review test; QA at 1440/390/320. Do not autosubmit, approve spec or spend on Grok. Keep current approved profile version untouched.
