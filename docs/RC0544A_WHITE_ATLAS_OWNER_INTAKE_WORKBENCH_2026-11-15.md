# RC054.4a — White Atlas owner intake overview, interview, review and spec
Date: 2026-11-15. Base Draft PR #58 exact SHA `0e1acd0fdfa6cf227de715038ffd41389dd25f10`.

## User / goal
Owner needs to read long real-world incoming requests and spec versions without scrolling a featureless wall of text, while preserving the verified client's privacy, explicit owner approvals, and no speculative AI/quote claims.

## Scope (presentation-only, no DB or ACL)
- Context-aware status/type pills (existing enum strings, no new statuses) and in-page anchor navigation.
- Separate original goal in a clean card; owner "current review position" text derived only from existing persisted spec/milestones, explicitly not a contract.
- Interview message feed: distinct client vs assistant styling; preserved original text, escaping, timestamps and label. Stimulus filters client/assistant/all purely as view visibility with no API calls or storage.
- Move existing interview form, admin spec controls, proposed milestone creation and client read receipt into clear visual sections *without changing their form routes/verbs or server policies*.
- Spec contents use existing `shared/white_atlas/spec_section` partial in a responsive two-column grid. Provenance/approval/version remain visible; no markdown HTML parsing of untrusted text.
- Data shape unchanged, current controller shows `@messages.order(:id).limit(20)`: **not full conversation history**. No pagination or full-history claim in UI.
- Four locale strings for section labels, neutral source warning, help and controls.

## Boundaries and QA
- No new business states or fake capability inference, no cost, no AI call, no migration, no production deployment.
- No client exposure to private drafts. Review `@latest_spec` access and exact role tests. Existing `client_reviewed_at` is *read receipt*, not scope acceptance.
- Keep existing `#intake-conversation`, technical spec section aria label and admin actions for compatibility.
- CI exact SHA Rails + Chrome + Security; local visual owner request #1 and #2 (spec and no spec), client #1 stays unchanged; 1440/390/320 and keyboard filter.
- Next `RC055.0`: unread persistence and owner inbox badge only after staging/local DB backup and migration review.
