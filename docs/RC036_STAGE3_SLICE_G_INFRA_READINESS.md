# RC-036 Stage 3 Slice G — storage capability audit + maintained local ClamAV
Date: 2026-11-11. Status: Draft PR #36, synthetic development ONLY. No Railway deploy or cloud resource was created.

## Deployment decision

Railway Storage Buckets are private S3-compatible storage, but **currently do not support server-side encryption, bucket lifecycle rules, versioning or object locks**. Official references:

- https://docs.railway.com/storage-buckets — unsupported S3 features and region/policy details
- https://docs.railway.com/storage-buckets/billing — $0.015 per GB-month; bucket operations/egress free, but Railway web service outbound upload may incur egress
- https://docs.railway.com/pricing — RAM $10/GB-month, CPU $20/vCPU-month at sustained equivalent consumption; volume $0.15/GB-month, network egress $0.05/GB (pricing/plan credit may affect billing)
- https://docs.clamav.net/manual/Installing/Docker.html and https://docs.clamav.net/manual/Usage/SignatureManagement.html — official image/FreshClam
- https://docs.clamav.net/manual/Usage/ClamdProtocol.html — TCP clamd is not authenticated or encrypted
- https://developers.cloudflare.com/r2/reference/data-security/ — R2 provider-managed encryption-at-rest (an alternative requiring provider-specific attestation rather than an AWS GetBucketEncryption response)

### Explicit release blocker

Do not connect any **real customer files** to Railway buckets while the release requires independent server-side encryption and lifecycle guarantees. A future design could add independently audited client-side envelope encryption and scheduled retention, but these are NOT yet implemented. A private bucket is not automatically an encrypted and lifecycle-managed bucket. For a separate real-data project, prefer a provider with independently verifiable encryption, explicit retention controls, least-privilege access, regional/legal review, and verified cost. Cloudflare R2 is a candidate, not an approved provider; S3 API capability coverage differs. Never assume that a green preflight means production acceptance.

## Added read-only bucket capability probe

File: `app/services/studio/nonproduction_storage_audit.rb`.
Execute ONLY against a dedicated synthetic test/dev bucket with credentials supplied through private environment variables, never flags or commits:

```sh
export RAILS_ENV=development
export RC_STUDIO_SYNTHETIC_STORAGE=true
export RC_STUDIO_QUARANTINE_BACKEND=s3
export RC_STUDIO_S3_PURPOSE=nonproduction-synthetic
# RC_STUDIO_S3_ENDPOINT=https://... (must be HTTPS)
# RC_STUDIO_S3_BUCKET=rc036-...
# RC_STUDIO_S3_REGION=...
# RC_STUDIO_S3_ACCESS_KEY_ID and _SECRET_ACCESS_KEY from private env
bin/rc036-nonproduction-s3-audit
```

Read-only API checks: bucket HEAD, four Block Public Access flags, policy non-public status, server-side encryption AES256/KMS, and enabled `q/` lifecycle expiry within 8 days. Unknown/missing/unimplemented provider APIs are treated as **false**, never assumed safe. No uploads, deletes, bucket creation or permissions changes. Output lists booleans only; no credentials/bucket IDs. This capability probe is intentionally AWS-S3-oriented; providers with different API capability surfaces must be reviewed separately. **Even all PASS does NOT allow production or customer uploads.** Do not use it to interpret a Railway bucket as passing a feature it does not implement.

## Official ClamAV local development stack

```sh
docker compose -f deploy/rc036/clamav.compose.yml up -d
```

Official `clamav/clamav:1.4` (preloaded signatures) runs clamd + FreshClam and persists signature DB in a local Docker volume. Image includes official signatures; FreshClam is enabled with 12 checks per day. Observe live container logs and confirm updates before testing any actual scan. The image is not pinned to a patch digest: pin a reviewed digest before real deployment. As advised by ClamAV, plan approximately 4GB RAM. Bind TCP to **127.0.0.1:3310 only**. Do not expose clamd over the public internet or use unauthenticated unencrypted remote TCP.

For a *local* Rails dev process, use `STUDIO_CLAMD_TCP_HOST=127.0.0.1`, `STUDIO_CLAMD_TCP_PORT=3310`, `STUDIO_CLAMD_UNIX_SOCKET` unset, and `STUDIO_CLAMD_REQUIRE_FRESH_DB=true`. The scanner queries `zVERSION` and refuses missing/unparsable DB timestamps or signatures older than 96 hours, then uses `zINSTREAM` with 64KiB frames. This is an **age heuristic, not cryptographic attestation** that official CVD databases were used. FreshClam update logs and DB provenance still require operational review. Existing isolated CI synthetic EICAR test continues over UNIX socket.

```sh
docker compose -f deploy/rc036/clamav.compose.yml logs --tail=100
docker compose -f deploy/rc036/clamav.compose.yml down
```

**NOT deployed:** no private Railway ClamAV worker, scheduler, dedicated staging service, paid bucket, production secrets, production migrations, real email delivery or user files.

## Current cost reality and next approval gate

Storage charge for a 1GB average bucket alone is roughly $0.015/month; that is not the cost of a running scanner. Official ClamAV container guidance recommends approximately 4GB RAM, which at Railway's $10 per GB-month would be roughly $40/month for a full month of 4GB RAM use, **before CPU, service egress, and volumes**, and it may vary depending on actual usage and plan credits. Do not create the 24/7 service without a documented monthly hard limit.

Before provisioning agree explicitly: provider, separate nonproduction environment, storage region, budget cap, accepted encryption/lifecycle design, protected secrets, scanning process isolation, startup health/freshclam update, purge monitoring and incident handling. The owner opted not to perform backup/restore exercises in this development iteration; recovery remains unverified.

## RC-036/RC-037 release gates

- [x] Synthetic S3 + genuine ClamAV EICAR integration on CI (prior Slice D).
- [x] Email-possession and separate client-session prototype, exact intake-scoped grants (prior Slice F).
- [x] Read-only S3 capability preflight and local official ClamAV/FreshClam compose are included as code.
- [ ] Confirm actual provider and monthly spend limit; physically provision durable private bucket and **verify** encryption/retention/privacy.
- [ ] Deploy and verify refreshed **official** AV signatures, isolated scan worker/queue, timeouts/retry and continuous audit.
- [ ] Complete legal/UX consent and real identity/SMTP, threat model, manual real-staging E2E, revoke/IDOR.
- [ ] Merge/release only after explicit permission and successful security acceptance. Until then production uploads disabled and RC-037 external paid AI OFF.
