# RC-021 — P0 admin HTTP access, delete Cancel and recovery drill

**Date:** 2026-11-07  
**Status:** Draft security gate; [Rails CI #42386758850](https://github.com/TheGor-365/rails_calendar/actions/runs/42386758850) and [Security #42386758844](https://github.com/TheGor-365/rails_calendar/actions/runs/42386758844) SUCCESS on code SHA `cf6791021327cd1e00f152c739a10d53d4b3c534`: 94 server tests/636 assertions + 19 Chrome tests/245 assertions = **113 tests / 881 assertions**, 0 failures/errors/skips. Isolated test checks pass; actual staging/manual gates remain open.  
**Stacked on:** [RC-020 #21](https://github.com/TheGor-365/rails_calendar/pull/21).

## Evidence, not assumptions

**Owner screenshots (2026-11-07):** On existing consultations index, authenticated administrator sees "Reschedule" under both #3 and #4. Navigating #4 opens `/consultations/4/edit#consultation_start_time` with original 13 Nov 2026 11:00–12:40 UTC. This visually passes **one-hop navigation and prefilled form**, not a performed update or Cancel. No overlap advisory is expected because #3/#4 do not overlap.

Previous RC-018 production-like model test yielded `[false,false,false,false,false,true]`; this is a **model decision test**, not user-confirmed HTTP traffic against live local Puma. Prior CI already had an HTTP login throttle test. RC-021 adds explicit isolated request-level tests for HTTP 429, cookie non-issuance on blocked attempts, successful session/logout and a simulated DB outage giving HTTP 503. It also adds a Selenium `dismiss_confirm` regression that preserves the exact fixture record after clicking Cancel. These tests run only against the disposable **test** database.

## P0 release gate matrix

| Check | Code evidence | Owner/environment acceptance |
|---|---|---|
| Private calendar guest redirect | RC-017 automated tests + owner incognito screenshot | Passed locally, real client/tenant privacy still **blocked** |
| Shared login limiting | RC-018 PostgreSQL atomic counter; owner six-call synthetic model PASS | Browser/Puma endpoint 429 after five wrong submissions **not manually verified** |
| Missing database during login | RC-021 isolated simulated DB-failure HTTP 503 regression | Actual outage/failover and monitored alert in staging still unverified |
| Sessions/logout/expiry | Existing controller tests, RC-021 request tests | Cookie Secure/SameSite, HTTPS termination and CSRF acceptance on staging still open |
| Delete exact-record confirmation | RC-015 record ID/title/time; RC-021 Chrome Cancel regression | Selenium Cancel is tested on isolated fixture. Do **not** manually trigger destructive controls on owner records #3/#4; optional owner UI check only on an explicitly approved disposable staging record |
| Database backup | Owner's custom archive created using pg_dump 18.6 against PG16.11, readable by pg_restore 18.6 | Actual **restore into separate isolated DB not yet done** |
| Proxy IP identity | HMAC of `request.remote_ip`; DB window shared | Review real proxy chain/forwarded headers so spoofing or shared NAT cannot compromise limits |
| Tenant/private client records | Demo-only single administrator, no row scoping | **Block real multi-client rollout** until identity/ACL designed and tested |

## Restore drill SOP — document only; do not execute on production

Only after explicit owner approval on an **isolated staging PostgreSQL instance**, with sufficient storage and no real client data:

1. Keep `~/.local/share/rails_calendar/backups/ruby_calendar_pre_rc018_2026-11-07.dump` private (0600). Confirm SHA256 checksum. DO NOT push it to GitHub/Notion or paste into chat.
2. Use **`/usr/lib/postgresql/18/bin/pg_restore`** for this archive (custom header version 1.16 was made by pg_dump 18.6). pg_restore 16.11 cannot read this archive.
3. Create a **new empty staging database** with a unique disposable name. Abort if that DB name exists. Never restore into `ruby_calendar`, `ruby_calendar_test`, or any live/production database.
4. Restore with `pg_restore --exit-on-error --no-owner --no-privileges --dbname=<NEW_STAGING_DB> <private.dump>` on the isolated staging PostgreSQL instance; validate table names, schema_migrations and record counts/IDs without exposing client data. Confirm app boot/migration separately. Retain staging DB until explicit teardown approval.
5. Never perform a `dropdb`, overwrite, table truncate or rollback on the owner's local/project DB as part of this gate. Restore steps here are **not** evidence of a completed restore.

## Conflict policy — Decision record proposal, not yet adopted

Until the business has confirmed whether a consultation is an exclusive single-person slot or can overlap across projects/consultants/resources:

- **Current rule:** overlapping `[start,end)` intervals are allowed; show admin-only advisory; no automatic relocation/deletion.
- **Proposed next domain design:** explicit `resource_id` (provider/team), per-resource capacity, status `draft/confirmed/cancelled`, immutable reschedule-history event with actor and before/after UTC instants, optional reason. Do not add these fields before approval.
- **Tradeoff:** enforcing single-slot capacity now would incorrectly reject valid concurrent deliveries. Conversely allowing confirmed double bookings without explicit resource capacity risks missed commitments. Owner must decide policy per resource/type.
- **Timezone:** application currently uses UTC consistently. Armenia-local inputs and multi-region DST require separate approved ADR; never silently convert historical records.

## Next actions

1. **CI/Security PASS** on code SHA `cf67910` (113 tests/881 assertions). Recheck final SHA after documentation-only checkpoint commits; keep Draft unmerged/undeployed.
2. Do **not** click Destroy on existing local records #3/#4 for manual QA. The isolated Chrome test verifies Cancel safely on a fixture; any supplementary human Cancel check must use an explicitly approved disposable staging record. The live Puma HTTP limiter may be checked on localhost without sharing credentials.
3. Authorize a separate staging restore rehearsal and decide booking/capacity + audit scope before stateful P1 changes or any release.

**No new migrations, services, paid resources, records or production mutation in RC-021.**
