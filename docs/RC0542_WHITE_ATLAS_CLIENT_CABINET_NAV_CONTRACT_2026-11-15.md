# RC054.2 — White Atlas client cabinet and canonical navigation
Date: 2026-11-15. Base: RC054.1 exact SHA 844d29cd2d2cbcfbd0afad45deee58d1cad84d40. Draft only; no Railway release.

## Verified UI issue / scope
- Desktop and mobile navigation exposed both `/client/cabinet` ("Client cabinet") and `/client` ("My cabinet"), even though both resolve to `ClientHomeController#show`.
- When viewing `/client/requests/:id`, "New request" was falsely active.
- Current request list used plain type/status text and a weak empty state.
- Owner screens, calendars, forms, DB, client ownership, verification and feature gates are unchanged.

## Decisions
- Canonical destination for the single nav entry: `/client` ("My cabinet"). Existing `/client/cabinet` still resolves to the same page for bookmarked links; do not remove/redirect it in this slice.
- Detail/review sections highlight the "My cabinet" section; new/create highlight only "New request"; `aria-current=page` appears only for the actual canonical/alias or creation page.
- Mobile client dock: My cabinet / New (only if pilot enabled) / Overview / Logout; no extra same-destination entry.
- Both existing routes render exactly one heading. Client list shows separately labeled stored type and status pills; empty list has a real create link. All text escaped by ERB.
- No speculative steps, no false contract status, no duplicate offers.

## Gates
- Exact-SHA Rails, Chrome and Security PASS with logs.
- Client: `/client`, `/client/cabinet`, `/client/requests/1`, `/client/requests/new`, with desktop 1440, mobile 390/320 screenshots and keyboard + focus.
- Owner cannot see client-only navigation; verified client sees only their own request; disabled pilot omits new-request action.
- Confirm previously approved owner/calendar screens unchanged; real UI approval before RC054.3.
