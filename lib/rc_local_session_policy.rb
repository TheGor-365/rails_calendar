# Session extension for one explicitly opted-in LOCAL development preview.
# Production and tests keep the original eight-hour, revocable DB session.
# A persistent cookie is additionally configured only for local development;
# Chrome Incognito still discards it when all Incognito windows are closed.
module RcLocalSessionPolicy
  DEFAULT_LIFETIME = 8 * 60 * 60
  LOCAL_LONG_LIFETIME = 14 * 24 * 60 * 60

  def self.enabled?(environment: Rails.env, flag: ENV["RC_LOCAL_LONG_SESSIONS"])
    environment.to_s == "development" && flag == "true"
  end

  def self.session_lifetime(environment: Rails.env, flag: ENV["RC_LOCAL_LONG_SESSIONS"])
    (enabled?(environment: environment, flag: flag) ? LOCAL_LONG_LIFETIME : DEFAULT_LIFETIME).seconds
  end
end
