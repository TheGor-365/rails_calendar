# RC-026 — staging HTTPS, proxy boundary, admin cookie and CSRF review

**Date:** 2026-11-08. **Parent:** [RC-025 Draft PR #25](https://github.com/TheGor-365/rails_calendar/pull/25). **Status:** Draft code hardening + isolated HTTP regression checks. **No Railway release, migration or owner DB modification.**

## Verified source-code facts

- Production already uses `config.force_ssl = true`, which activates Rails SSL middleware (redirect, secure cookies and HSTS). Staging actual ingress/TLS configuration has not been verified. Rails `config.assume_ssl` is **not** enabled here because an untrusted/directly exposed ingress could mask plaintext HTTP.
- Existing administrator sessions are encrypted cookies, expire by server-side timestamp after 8 hours and are invalidated by credential rotation. Logins are subject to PostgreSQL shared HMAC-IP throttling; real IP interpretation depends on verified trusted proxy hops.
- The HTML layout uses `csrf_meta_tags` and Rails-generated `form_with` forms. In `RAILS_ENV=test` CSRF protection is disabled by default; previous passing request specs did not independently prove token/origin rejection. New isolated integration tests explicitly enable forgery verification for their scope and restore global settings after each test.
- Production calendar is private by default unless `RAILS_CALENDAR_PUBLIC_DEMO_MODE=true` is explicitly set. That switch should **never** be used on client data.

## Narrow RC-026 code change

- Explicit `CookieStore` options: fixed host-only `_rails_calendar_session`, `HttpOnly`, `SameSite=Lax`, `Path=/`, `Secure` when `Rails.env.production?`. No broad cookie domain. Existing sessions using a different cookie key may need to sign in again; credential rotation already invalidates them by design.
- Explicit `config.action_controller.forgery_protection_origin_check = true`; never use `skip_forgery_protection`, `:null_session` for authenticated HTML writes, or disable TLS validation.
- New isolated request specs cover form token presence; blocked login without token, rejected cross-origin login/update, blocked mutation/logout without token, successful same-origin login, configured session cookie policy and browser `Set-Cookie`. Tests verify behavior **in test mode**, not public TLS.

## Mandatory staging acceptance — evidence not yet obtained

**Owner must first identify the intended staging hostname and trusted reverse-proxy topology, and explicitly approve connecting/deploying to that nonproduction environment.** Do not deploy to an unknown Railway project.

1. Check actual public `https://<approved-host>/admin/login` certificate validity, no mixed content, origin and host alignment. Follow an HTTP request to verify redirect exactly once to HTTPS (no loop), and inspect HSTS. Avoid arbitrary HSTS `includeSubDomains` on a shared apex: set domain policy only after host review.
2. Check **real** `Set-Cookie` after a successful admin login in developer tools: session host-only, `Secure`, `HttpOnly`, `SameSite=Lax`, no accidental Domain, cookie not returned to plain HTTP. Do not put cookies, bearer tokens, passwords or response bodies into tickets, logs, screenshots or this PR.
3. Confirm proxy forwards correct scheme/host and limits/trusts the chain: inspect `X-Forwarded-Proto`, `X-Forwarded-For`, `X-Forwarded-Host` at the ingress without trusting arbitrary client-supplied spoofable headers. Application origin checks must compare the actual browser HTTPS origin. Ensure app container/HTTP port is not directly Internet-reachable. Never use `assume_ssl = true` solely to suppress a redirect loop.
4. With a disposable **staging test administrator account** and **synthetic data**, verify form login and logout with valid CSRF, forged/absent token rejection (no write and no session), cross-origin request rejection, cookie expiry, browser stale-edit HTTP 409, real per-IP login throttling under intended proxy topology. Do not test against owner consultations #3/#4.
5. Verify secrets live in an approved secret manager; rotation revokes previous admin cookie. Fail closed if admin username/password, DB or Rails secret are missing. Do not include raw IPs or secrets in evidence.

## Current scope boundary

This review cannot establish the public network's true TLS termination, DNS ownership, proxy chain, security group/firewall, Railway service identity, cookie attributes over **actual** HTTPS, or business-specific session policies without a verified staging endpoint. CI success is evidence of the code tests only. **No merge/deploy, no real records, no new paid resources.** Separate per-user/tenant ACL and audit retention remain blocking before exposing real customer data.

## Sources

- [Rails SSL middleware](https://api.rubyonrails.org/v8.1.3/classes/ActionDispatch/SSL.html)
- [Rails 8.1.4 CSRF protection](https://api.rubyonrails.org/v8.1.4/classes/ActionController/RequestForgeryProtection.html)
- [Rails session configuration](https://api.rubyonrails.org/v8.1.4/classes/Rails/Application/Configuration.html)
- [Rails security guide](https://guides.rubyonrails.org/security.html)
