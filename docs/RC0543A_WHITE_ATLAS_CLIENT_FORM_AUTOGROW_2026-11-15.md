# RC054.3a — White Atlas client request form and native textarea auto-grow
Date: 2026-11-15. Base exact SHA 49cb911c93cffb227e699d60541a04f9f602310f. Draft only; no merge or production release.

## Scope and invariants
- Only `client_requests/new` is visually restructured: three sections (basics, task, fictional-data consent), existing form action and Rails fields retained.
- Accessible helper text plus live character count (output, not noisy screenreader announcements); max remains 1,200 and the server limit is unchanged. New translations exist in en/ru/hy/es.
- Opt-in `wa-autogrow` Stimulus controller registered explicitly in existing application. It resizes native textarea based on content, shrinks on deletion, caps against CSS viewport max-height, handles window resize, and cleans only inline sizing before Turbo cache and disconnect. **Never changes value or form submission**.
- Legacy `rc-select`, `ui-feedback`, CSRF, consent, client verification, account ownership, and controller+DB are untouched.
- No blanket global textarea redesign: controller is applied only to this client form in RC054.3a. Owner intake/spec and consultations are RC054.3b pending independent visual QA.

## Acceptance checklist
1. Exact-SHA Rails, Chrome, security PASS; verify test counts and errors from logs.
2. Local JS/CSS builds PASS; verified client sees the form in en/ru/hy/es. Check `/client/requests/new` and unchanged `/client/requests/1`.
3. Test 1440, 768, 430, 390 and 320 widths; no horizontal overflow; keyboard Tab/focus visible, long multiline pastes, shrink/undo, 1200-character native limit, short 10-character validation.
4. Confirm missing consent / invalid server inputs still render clear errors and preserve entered fields; Turbo revisit does not clear content from Stimulus.
5. Owner navigation and protected workspace remain stable. No real data in local pilot, no paid Grok without explicit consent.
