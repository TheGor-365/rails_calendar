# RC-037 — owner acceptance and production release gates (11 Nov 2026)

**Status: blocked for production.** Draft PR #37 and Draft PR #36 remain unmerged. This record distinguishes GitHub CI browser evidence from a user's actual local machine check.

## Verified in isolated CI

- Synthetic offline dispatcher: no provider SDK/egress, zero billed tokens and USD, owner + workspace/intake/client ACL, HMAC policy audit admission, deterministic golden templates, tampering/revocation tests.
- Signed, tenant-scoped offline run ledger and one owner synthetic-only review; production controller 404 and no customer source bytes.
- Automated Chrome browser route (new `test/system/studio_offline_review_flow_test.rb`) at widths **320 / 390 / 430 px** verifies layout overflow, controls, focusable semantics via explicit label+skip-link, preview→record→review, denied policy and tampered run history.
- Dedicated `bin/rc037-local-acceptance` refuses remote/production DB and only permits `localhost/ruby_calendar_test`. It runs disposable `db:prepare`, RC-037 Rails tests and Chrome system tests; no external model or real client content. `--check-only` validates guard without touching DB.

## Not yet independently verified — ALL still release-blocking

| Gate | Status | Required evidence |
| --- | --- | --- |
| Owner Linux Mint 22.1 local end-to-end | **AWAITING USER** | Command stdout + screenshots for owner workflow, browser ChromeDriver present |
| Visual mobile UX at 320/390/430 on owner's Chrome | **AWAITING USER** | Screenshot at each width + keyboard review + visible validation/errors |
| Malware scanning with actual current ClamAV signatures | **UNVERIFIED** | Nonproduction signed scan tests; fake test scanner/EICAR signature alone insufficient |
| Private durable encrypted object storage, retention/key rotation | **UNVERIFIED** | Nonproduction encrypted storage test and ACL/quarantine audit; currently production buckets empty |
| Verified client identity and lawful processing consent | **UNVERIFIED** | Actual permission evidence before importing real client data |
| DB + object-store backup **and restore** | **UNVERIFIED** | Dry-run restored DB and blobs, manifest hashes, operator evidence |
| Real-provider expense caps/reservations/reconciliation | **NOT IMPLEMENTED** | Concurrency tests and explicit owner approval; external providers must remain off |
| Independent audit immutability | **UNVERIFIED** | External write-once anchor, separate key custody; HMAC does not make DB WORM |
| Production release approval / merge | **NOT GRANTED** | Explicit separate instruction only after all mandatory gates |

## Local owner instructions (Linux Mint; use test-only DB)

1. In an **up-to-date checked-out** `rails_calendar` branch `feat/rc037-ai-offline-policy-2026-11-11`, install gems and JS dependencies using normal repo tooling and ensure local PostgreSQL and compatible Chrome/ChromeDriver are available. Never point `RC_LOCAL_TEST_DATABASE_URL` at Railway or a customer DB.
2. In Linux Mint terminal (no secrets shared in chat), run:

   `env -u DATABASE_URL PGHOST=127.0.0.1 RC_LOCAL_TEST_DATABASE_URL=postgresql://postgres@127.0.0.1:5432/ruby_calendar_test bin/rc037-local-acceptance`

   If local PostgreSQL requires password, supply it privately via local `PGPASSWORD` or adjust user portion of URL; do not post credentials. Script uses test database only and emits terminal `PASS` or `FAIL`; `production_ready` is always false.
3. Send terminal last lines and optionally owner-page screenshots at 320/390/430; review UI on keyboard and note actual overflow, clipping, source-selection and duplicate-review errors. This is separate from CI passing on Ubuntu.

**Production remains RC-035 on Railway; `$0` added paid resources.** No release/merge/deploy. After evidence, decide whether to open a separately stacked synthetic-only RC-038 Draft PR; this does not imply RC-037 is production-ready.
