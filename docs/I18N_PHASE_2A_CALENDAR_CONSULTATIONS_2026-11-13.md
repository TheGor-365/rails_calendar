# i18n Phase 2a — Calendar & Consultations (2026-11-13)

Base: i18n Phase 1 Draft PR #46, expected exact base SHA `286c2a5dc6d9a76dac06abccf41152ce5112c098`. Safe stacked Draft PR; no DB migration, paid AI, API keys, merge or deployment.

## Coverage
- Month, day and hour calendar: labels, accessible names, date and month names, empty states, descriptions, left/right navigation, and mobile agenda. The **24-hour timeline, overlap-lane positioning, links, IDs, ISO dates, inputs and UTC semantics remain untouched.**
- All seven consultation templates: list, GET filters, status labels with unchanged query values, pagination, detail, create/edit, reschedule history, overlaps, safe deletion confirm, duration, and field hints.
- Backend user-facing validation errors, search errors and success notices translate per request; immutable audit `actor_label` and stored consultation titles/descriptions are **not translated**, never mutated.
- Separate `config/locales/<language>/calendar.yml`, `consultations.yml`, `calendar_dates.yml`, and `consultation_attributes.yml`; English canonical; Russian count inflection one/few/many, other languages one/other; date/time presentation uses I18n.l.
- No change to timezone, booking collision policy, record read authorization, owner vs legacy admin login, or accounting.

## Remaining slices
- i18n Phase 2b: Synthetic Intake Quiz, review, project spec editor, project hub, shared workflow, validation/flash messages; separate PR and E2E.
- AI interface: no real provider call. Must first run mock-only owner workspace journey using synthetic data. Real xAI is gated by budget ledger/reservation, egress allowlist, secret storage, privacy and explicit consent for any billable call.
- Production: remain on pinned RC-035 until stage by stage backup/restore, DB compatibility, smoke QA and explicit approval.

## QA
CI Rails full + Chrome full + Security Audit on exact HEAD. Local viewport 320,390,430,1280 for EN/RU/HY/ES; keyboard focus, date links, admin creation flow, stale-tab edit, schedule overlap, month/day/hour and zero/long records. This does not imply professional localization review for HY/ES or legal translations.