# RC-026: explicit browser-session cookie policy. No Domain means host-only.
# Rails production serves only behind a separately verified TLS ingress.
# Never enable 'assume_ssl' until proxy trust and ingress isolation are proved.
Rails.application.config.session_store(
  :cookie_store,
  key: "_rails_calendar_session",
  path: "/",
  httponly: true,
  same_site: :lax,
  secure: Rails.env.production?
)
