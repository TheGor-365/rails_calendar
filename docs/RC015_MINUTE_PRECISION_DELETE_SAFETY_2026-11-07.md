# RC-015 — Minute-only scheduling and identifiable deletion

**Date:** 2026-11-07. **Status:** implementation candidate; manual acceptance and final CI are required.

## Confirmed user evidence / incident

User's browser screenshots from the Rails Calendar P0 manual test show:

- **Create PASS:** `/consultations/3` showed “Consultation was successfully created” with title `RC-P0 QA — DELETE AFTER TEST`, 12 Nov 2026 09:00–09:30 UTC.
- **Navigation PASS:** the new appointment appeared in 12 November monthly/day views and consultation index.
- **Update PASS:** `/consultations/3` showed “Consultation was successfully updated”, but the edit form revealed a legacy end-time field with seconds, `09:30:07`.
- **Delete incident:** a confirmation prompt was captured on **`/consultations/2`** showing the original title `New` behind it; the next page showed “Consultation was successfully destroyed” and the list now contained **only** `RC-P0 QA — DELETE AFTER TEST`. Strong evidence that original consultation **#2** was deleted, whereas temporary #3 remained. This is a *local data-loss incident*, not a verified successful cleanup. The current DB is not accessible from GitHub; **do not assert that the original has been restored**.

**Safety constraint:** Do not silently recreate #2, reuse primary keys, delete #3 or run DB reset/migration without verifying the local DB, checking backups and getting the owner's explicit decision. Prior screenshots show #2 originally titled `New`, description `Description for consultation`, 07 Nov 2026 23:54 UTC → 08 Nov 2026 22:53 UTC. These can assist a reconstruction plan but are **not a verified backup**; any recreation would receive a new ID unless an audited restore process is chosen.

## Code changes

1. Input `datetime-local` displays **HH:MM only** with `step=60`; form text says minute precision and UTC, no seconds control.
2. New or actually modified start/end instants are validated on the server to be exact minutes (seconds and fractions zero). Invalid time returns 422 and the existing inline error panel.
3. **Legacy conservation:** if an old record has nonzero seconds and the editor resubmits the *same displayed minute*, controller omits that unchanged datetime attribute so a text-only edit does not silently discard its stored seconds. When user changes a minute, newly submitted minute-granularity time is stored; no bulk migration.
4. Destructive confirmation now names consultation ID, title, date/time, and states that the operation cannot be undone. That makes accidental deletion of the wrong record much easier to detect. It is **not** a substitute for a reversible audit/tombstone system; soft-delete + restore remains a separate future design requiring a migration and approval.
5. Integration and Chrome regression tests check minute-only widgets, precise server validation, legacy preservation, and record-specific confirmation.

## Gates

- [ ] Rails CI + Security audit green on same final SHA.
- [ ] Owner local test on 320/430/mobile and desktop. New/Edit datetime fields must show HH:MM only.
- [ ] Read-only verification of local records #2 and #3, backup status, and whether the owner wants original #2 restored (no automatic changes).
- [ ] Test delete confirmation only against a deliberately created **new** synthetic record and inspect that ID/title match; never use original record.
- [ ] Verify guest ACL, session expiry and login rate-limit behavior. No production/main/Railway modification.

## Continuation

After P0 resolution: timezone/display ADR (UTC instants, explicit Armenia/client TZ behavior, DST), then PR chain/release review; later P1 filters and P2 AI Intake. **Mobile functional parity and human-approved destructive actions remain permanent acceptance criteria.**
