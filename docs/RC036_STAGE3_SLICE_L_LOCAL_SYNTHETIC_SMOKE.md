# RC-036 Stage 3 / Slice L — local synthetic smoke, $0

**Status: implemented in Draft PR #36; exact-head CI and owner-machine run must be recorded separately.** No production deployment, customer documents, paid bucket, paid ClamAV or paid AI.

## Mode A — one command with real Rails/PostgreSQL/HTTP and a FAKE test scanner

The executable `bin/rc036-local-smoke` runs only `RAILS_ENV=test` and only against a **dedicated local** database named `ruby_calendar_test`. It refuses a `DATABASE_URL`, a remote PostgreSQL host, and production RAILS_ENV/RACK_ENV. It forces the quarantine backend to local DiskService and runs `test/integration/rc036_local_smoke_test.rb`. It **does not** scan any user's real documents, run a development worker, or mark development blobs clean.

Use the existing Rails 8.1.4.1 / Ruby 3.4.12 + Bundler + local PostgreSQL on Linux Mint. From the existing checked-out RC-036 branch:

```sh
bundle install
export RC_LOCAL_TEST_DATABASE_URL="postgresql://postgres@127.0.0.1:5432/ruby_calendar_test"
RAILS_ENV=test bin/rails db:prepare
bin/rc036-local-smoke
```

Use the operator's local PostgreSQL credentials **only in a private environment**, never commit or paste passwords/tokens into a ticket. The `ruby_calendar_test` DB is a disposable local **test database**, not development or production. Rails tests may replace its contents. If local PostgreSQL is not configured, stop; do not point this command at Railway or a customer DB.

### Assertions (fictional MD/TXT/JSON, max 256 KiB)

1. Owner HTTP multipart staging writes a random-key private quarantined disk object, source hash and metadata; bytes cannot be downloaded before clearance; HTTP replies are `no-store`.
2. Owner HTTP enqueue returns `queued`, not a scan verdict. A **test-only fake** scanner processes the PostgreSQL queue; matching SHA256, TTL and owner policy allow a clean attachment solely in test.
3. Guest redirects to sign-in; a different owner/workspace, different client, wrong intake and revoked membership cannot read clean bytes. No private key or source content is emitted by the health JSON.
4. Fake infected TXT remains forbidden, even with a terminal queue record. JSON source expires without scanning; a separate manual retention sweep physically removes its bytes and retains revoked metadata.
5. Archive magic spoofed as MD is rejected; final CLI JSON contains only PASS/FAIL, test/assertion counts and nonproduction caveats. Failure exit code is nonzero; all created test disk objects are removed in teardown.

A **PASS proves application behavior with a synthetic fake scanner**, not an antivirus signature database, customer privacy acceptance, durability, or production readiness. The real browser on the owner's Linux machine is **not tested** until the owner actually runs the command and shares the summary. The CI runner is not the owner's computer.

## Mode B — genuine temporary S3+clamd CI, independently verified

Existing workflow `.github/workflows/rc036-private-s3-clamd.yml` launches disposable loopback SILO and real clamd, tests clean/infected HTTP, anonymous GET denied and retention. It uses **only one EICAR synthetic signature**, not an officially maintained FreshClam production database. Never call this a real malware-coverage certification. This workflow runs on RC-036 branch updates with no new paid cloud resource.

Optional owner-local SILO/ClamAV Compose setup remains in the existing [Slice K](RC036_STAGE3_SLICE_K_LOCAL_RECOVERY_AND_CHECKPOINTS.md) runbook; it is separate from Mode A. The user has not confirmed those containers on their own machine.

## Acceptance tracking

- [x] Dedicated executable smoke wrapper with a strict local **test DB** and disk-only boundary.
- [x] Integration tests for quarantine → queue → clean/denied → infected/expired/revoked → physical retention and sanitized health.
- [ ] New exact-HEAD CI result and test counts; do not reuse Slice K green runs.
- [ ] Real owner-machine command evidence and optional local genuine FreshClam signature-readiness proof.
- [ ] Human browser acceptance 320/390/430, security/legal/client identity, encrypted private durable storage, actual backup AND restore before any production release.
