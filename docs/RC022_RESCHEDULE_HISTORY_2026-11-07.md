# RC-022 — Administrator reschedule history

**Date:** 2026-11-07  
**Status:** Draft implementation. [Rails CI #42388655729](https://github.com/TheGor-365/rails_calendar/actions/runs/42388655729) and [Security #42388655663](https://github.com/TheGor-365/rails_calendar/actions/runs/42388655663) SUCCESS on code SHA `e96c3662580e3a208dd68db5703b56f7f8700b50`: 103 Rails tests/709 assertions + 20 Chrome tests/273 assertions = **123 tests/982 assertions**, 0 failures/errors/skips. Manual staging/migration approval outstanding. Stacked on RC-021.  
**Contract:** [ADR-002](ADR002_RESCHEDULE_AUDIT_CAPACITY_2026-11-07.md).

## Feature scope and behavior

- Existing `Consultation` CRUD and read-only public (development)/private (production) calendar remain unchanged.
- Existing administrator `Update Consultation` accepts an optional form field `reschedule_reason` (1–500 characters **required only when start/end time actually changes**).
- Server-side `Consultations::Reschedule` service checks for a real time change, saves under row lock and inserts one audit snapshot inside the same PostgreSQL transaction. It does **not** require a reason for title/description changes and preserves unchanged legacy-second timestamps.
- Snapshot table `consultation_reschedule_events` stores consultation ID, exact old/new start/end UTC instants, server actor role `administrator`, reason and UTC creation timestamp. No existing rows are rewritten. Current physical delete leaves audit snapshots retained (no FK cascade), subject to a future privacy/retention policy.
- Consultation details show up to 20 latest snapshots only for an authenticated administrator. Guest HTML and the existing consultation list do not expose reasons or history; controller continues to deny guest writes.
- Required reason validation displays inline and returns HTTP 422 with no change if missing/too long. Overlap warnings remain **nonblocking** (RC-020).
- Responsive Chrome checks cover the reason field, history and fixed dock at widths 320/390/430. CSS uses existing Slate & Tide/bootstrap-icons.
- Parameter `reschedule_reason` is redacted by Rails log filter. Reason stored inside private DB/backups is not anonymized.

## Scope exclusions and risks

- This is **not proof of client acceptance**. Current single administrator account cannot identify an individual actor or origin device. Logs are application-level immutable, not enforced against privileged direct SQL or non-HTTP bulk updates.
- No resource/staff/capacity ownership, status, hard conflict rejection, notifications, schedule suggestions, external integrations, multi-tenant ACL or automatic event moves.
- A concurrent stale form could override a newer write; row locking gives consistent logged before/after DB values but does **not** replace optimistic locking. Address before multi-actor use.
- Hard-deleted consultation audit rows remain in DB, not visible via deleted consultation's detail page; privacy deletion/retention unresolved.
- Test code uses isolated fixtures, not local records `#3` or `#4`.

## Release acceptance

- [x] CI + Security green on code SHA `e96c366` (123 tests/982 assertions); documentation-only final HEAD still to verify; Rails tests assert missing/long reasons rejected, valid moves generate precise old/new snapshots, text-only edits and untouched legacy minutes never audit, guest cannot mutate/read history, changed record deletion leaves snapshot, script content escaped, readonly model blocks modifications.
- [ ] Chrome system tests 320/390/430: reason input accessible, fixed dock, history text wraps with no horizontal scroll.
- [ ] Owner confirms no stale form overwrite policy and approves DB migration in isolated staging **after** backup/restore rehearsal. Do not directly run a production or owner development migration from this chat.
- [ ] Owner sees edit #4 prefilled and that a title-only edit needs no reason (can Cancel without saving). Real reschedule may be tested exclusively on an owner-approved disposable staging record, not retained #3/#4.
- [ ] No merge/main or Railway change until the P0 release gates in [RC-021](RC021_P0_SECURITY_RECOVERY_GATE_2026-11-07.md) close.

## Source evidence

- Owner 2026-11-07 screenshots: #4 `Third`, 13 Nov 2026 11:00–12:40 UTC, visible Reschedule link from list and prefilled edit form. These screenshots **do not** evidence a successful move.
- Prior RC-021 code+CI 113 tests, 881 assertions; Security green; no physical staging restore or reverse-proxy/cookie/CSRF review yet.
- This branch adds migration, app service, server-only history rendering and new regression tests in a Draft PR.
