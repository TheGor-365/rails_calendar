# RC055.1f C2.1b White Atlas UI follow-up — 17 November 2026

Stacked on Draft PR #79. No production merge/deploy or source-database migration.

- Conversations: reuse established `surface-panel`, `rc-empty-state`,
  `rc-form` and `rc_icon_label` for a visually consistent fallback and
  clear, meaningful actions. Scoped `wa-threads` SCSS is already imported;
  after switching Git branches, execute `npm run build:css` to compile it.
- Client avatar: match existing owner-pencil editor, 1:1 crop preview,
  3 MB JPEG/PNG/WebP policy and append-only prior versions. Separate
  `client_avatars` attachments keep owner data isolated.
- Local verified-client-only routes and private, no-store image delivery.
  No public Active Storage blob URLs; other clients receive 404.
- No DB migration; Active Storage tables already exist. No AI-provider calls.
- Owner avatar flow and existing business objects are unchanged.

Gates: exact-SHA Rails/Chrome/Security CI, CSS/JS build, local 1440/390/320px
screenshots for conversations and both avatar editors; guest/client/owner IDOR,
keyboard Escape, crop/fallback, reload persistence, and no horizontal scroll.
Local review database: `rails_calendar_rc0551f_c21b_review_20261117`.
Do not migrate `rails_calendar_mvp_preview_20261112` or alter backups.

## 17 Nov exact-SHA QA incident

- First PR #80 SHA `e200df6`: model/controller tests and JS/CSS build passed.
- Browser job with Chrome 158.0.8127.36: 46/46 setup errors at
  `Capybara::Selenium::Driver::ChromeDriver#reset!`, because Chrome rejects
  wildcard origin in CDP `Storage.clearDataForOrigin`. No UI assertions ran.
- Temporary CI-only baseline pins Chrome/ChromeDriver 157.0.8103.78 to
  restore meaningful automated acceptance. Follow up with modern driver
  compatibility work; never count this as a Chrome 158 compatibility pass.
- Security Audit separately failed: `yarn audit` reports high
  `sass > @parcel/watcher > picomatch` ReDoS, currently no patch offered by
  the registry audit. Ruby audit/Brakeman passed. Do not suppress JS audit.
