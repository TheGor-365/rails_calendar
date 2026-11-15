require Rails.root.join("lib/rc_local_session_policy")

# RC-026: explicit browser-session cookie policy. No Domain means host-only.
# Production retains its browser-only, Secure cookie and eight-hour DB lifetime.
# Only the explicitly opted-in LOCAL development pilot receives a persistent
# 14-day browser cookie, matching the revocable UserSession expiry.
cookie_options = {
  key: "_rails_calendar_session",
  path: "/",
  httponly: true,
  same_site: :lax,
  secure: Rails.env.production?
}
if RcLocalSessionPolicy.enabled?
  cookie_options[:expire_after] = RcLocalSessionPolicy.session_lifetime
end

Rails.application.config.session_store(:cookie_store, **cookie_options)
