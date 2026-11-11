# RC-037 Slice B — local owner-only AI Settings screen

Existing stacked [Draft PR #37](https://github.com/TheGor-365/rails_calendar/pull/37). Additive Rails ERB/Bootstrap/Turbo, no SPA, no production deploy.

Routes: `GET/PATCH /workspaces/:workspace_id/project_intakes/:id/ai_settings`. Only an active owner with the exact workspace/intake may view or change settings. Rails production **404**, local development requires `RC_STUDIO_AI_OFFLINE=true`, tests require `RAILS_ENV=test`. Headers: private no-store, no-referrer, nosniff.

Two separate forms: workspace default and project-specific restrictive override. Only `off` and `offline` are accepted from UI; allowlisted purposes are strictly validated. Controller never permits mass assignment of `external_consent`, token/USD caps, provider identifiers, or secrets. Disabled workspace cannot be bypassed by project preference. Invalid params yield safe 422 without mutation. No automatic execution on save. UI accessible from existing synthetic Studio preview.

The interface never authorizes real client processing, external AI, token billing or execution in Railway production. No provider integrations, API keys or external HTTP. Tests: owner GET/POST, guest/foreign workspace/revoked owner denied, production hard deny, rejected hostile modes/purposes/targets, no cost escalation even via extra form parameters. Manual 320/390/430 acceptance remains pending.
