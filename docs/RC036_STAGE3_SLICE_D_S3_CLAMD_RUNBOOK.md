# RC-036 Stage 3 / Slice D — S3 + live clamd test contract

**Status:** Draft PR #36 implementation, NOT a production release. No real client files.

## Isolation and authorization

The quarantine flow stays owner-only. Studio::PrivateSourceStorage.enabled? is always false in Rails production. In Rails test, synthetic disk remains the default. An explicit S3 backend is selected ONLY with RC_STUDIO_QUARANTINE_BACKEND=s3 and ALL of:

- Rails environment test, OR development with RC_STUDIO_SYNTHETIC_STORAGE=true.
- RC_STUDIO_S3_PURPOSE=nonproduction-synthetic.
- Explicit S3 endpoint, region, bucket, access-key ID, secret-access-key via environment (no credentials in git).
- Separate bucket named rc036-..., unrelated to business/production storage.
- HTTPS for external endpoints; loopback http://127.0.0.1 / localhost allowed ONLY in Rails test.
- No public bucket policy, public ACL, signed blob URL or direct Active Storage routes.

The config/storage.yml S3 service uses force_path_style: true, public: false, bounded timeouts/retry. The app never creates a cloud bucket or changes Railway infrastructure automatically.

## Integration in GitHub Actions

.github/workflows/rc036-private-s3-clamd.yml runs only on pushes to the RC-036 feature branch and creates disposable resources:

1. PostgreSQL 15 test DB + pinned aws-sdk-s3 Ruby dependency.
2. Maintained S3-compatible PGSTY SILO image (released 2026-11-09), digest-pinned and used ONLY in CI, loopback 127.0.0.1:9000, randomly generated root password per runner, private rc036-ci-quarantine bucket.
3. GENUINE clamd daemon installed via apt, accessed using a private UNIX socket with INSTREAM. It loads a single synthetic **EICAR test signature**, not continuously updated official signatures. This proves protocol and test signature handling, NOT real-world malware protection coverage.
4. Explicit integration suite: bin/rails test test/integration/rc036_private_s3_clamd.rb. Intentionally excluded from the default *_test.rb test glob. Checks quarantine blocking, genuine clean/infected scan, owner-only HTTP attachment, unsigned direct S3 GET returns 403, cross-workspace/client/intake IDOR denial, revoked membership and expired object deletion.
5. No customer uploads, payment/billing changes, public domains, Railway deployment or external AI.

## Local dev configuration (only fictional files)

RC_STUDIO_SYNTHETIC_STORAGE=true
RC_STUDIO_QUARANTINE_BACKEND=s3
RC_STUDIO_S3_PURPOSE=nonproduction-synthetic
RC_STUDIO_S3_ENDPOINT=https://<dedicated-nonproduction-host>
RC_STUDIO_S3_BUCKET=rc036-<private-test-bucket>
RC_STUDIO_S3_REGION=<region>
RC_STUDIO_S3_ACCESS_KEY_ID=<injected-secret>
RC_STUDIO_S3_SECRET_ACCESS_KEY=<injected-secret>
STUDIO_CLAMD_UNIX_SOCKET=<local-private-socket>

Never share secrets, upload real client material or copy production data to this environment.

## Unresolved release gates

- [ ] Deployed maintained private durable S3 bucket; encryption, credential rotation, strict bucket policy, storage lifecycle and network review.
- [ ] Maintained live clamd with official fresh signatures and isolated production worker queue + retry, dead letter and bounded usage.
- [ ] Scheduling, audit, reliable cleanup/reconciliation of expired/orphan objects; concurrency/consent/privacy controls.
- [ ] Verified client identity, invitation redemption, exact ACL, browser/mobile QA and E2E security review.
- [ ] Owner approval before merge/deploy. No production change or paid infrastructure until explicitly approved.

Per user decision, no backup/recovery work is undertaken in this development iteration. Production recoverability is NOT verified.

**Production upload and download remain disabled.** Passing CI is synthetic integration evidence only.
