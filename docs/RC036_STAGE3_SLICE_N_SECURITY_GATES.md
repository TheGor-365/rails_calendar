# RC-036 Stage 3 Slice N — nonproduction-only preview and HTTP taint boundary

**Security review performed against Draft PR #36 after Slice M, no production release.**

## Concrete finding and patch

The owner-only `Studio::SourcePreviewsController` previously accepted and parsed in-memory unscanned MD/TXT/JSON in Rails production (although it never persisted source bytes). That contradicted the agreed nonproduction-only synthetic security boundary. The controller now **refuses both GET and POST in production**, even for the owner. Local development requires explicit `RC_STUDIO_SYNTHETIC_STORAGE=true`; the Rails test environment remains allowed. No real user files should be tested with this feature. Every response path applies `Cache-Control: private, no-store`, `X-Content-Type-Options: nosniff` and `Referrer-Policy: no-referrer` before authorization/early denial.

## Executable negative evidence

Additional HTTP tests prove the production gate returns 404 without staging files and synthetic Markdown containing raw `<img onerror>` or `<script>` remains safely HTML-escaped in the ERB/Turbo preview. Existing tests separately cover guest/foreign workspace/wrong intake/owner membership, archive/MIME/size/JSON restrictions, signed-like attachment denial until scan, and revoked/infected/expired access.

## Threat matrix (not a penetration-test certification)

| Surface | Existing control / current result | Residual release gate |
| --- | --- | --- |
| Source preview HTTP/Turbo | exact owner+workspace+intake; untrusted text escaped; nonproduction-only; no-store/no-referrer/nosniff | Manual browser/CSP/keyboard/mobile acceptance |
| Quarantine/download | private random key, SHA256, scan state, TTL and re-authorization on request; no public direct source URL | Encrypted durable production object store + actual AV/FreshClam |
| Session/CSRF | DB-backed revocable owner/client sessions and Rails CSRF controller default | Manual browser and production proxy E2E |
| Invitations/OTP | digest token/OTP, short TTL, browser-session-binding, minimal grant, no auto-file permission | Legal identity/consent wording, reliable email transport |
| PostgreSQL tenant isolation | composite tenant FK + raw SQL negative tests | Production migration and backup/restore |
| Source parsing | MD/TXT/strict JSON, size 256KiB, reject archive/executable magic; inert text | CSV/XLSX/PDF/DOCX/PPTX parser sandbox, decompression & SSRF guards |
| AI / remote fetch | no paid external calls, no remote URL fetch in this slice | Offline policy dispatcher, prompt-injection and retrieval ACL tests |
| Inventory/retention | bounded read-only inventory, manual purge only, no orphan delete | Independently audited complete storage lifecycle |

**Limitations:** CI-only negative tests are not independent security or penetration certification. Browser 320/390/430 and actual owner-machine Linux Mint run remain pending. No real customer data, production bucket, active worker, paid AI, SMTP, merge, Railway deployment, or destructive restore was involved.

Run `bin/rails test test/controllers/studio/source_previews_controller_test.rb` inside the existing dedicated test DB; the full exact-head GitHub CI must also pass before treating the patch as accepted.
