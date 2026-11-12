require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module RailsCalendar
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0

    # Four UI locales, English fallback during staged translation.
    # Calendar and data storage continue using UTC, not a regional timezone.
    config.i18n.default_locale = :en
    config.i18n.available_locales = %i[en ru hy es]
    config.i18n.fallbacks = true
    config.i18n.load_path += Dir[Rails.root.join("config/locales/**/*.{rb,yml}").to_s].sort


    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # Contract for the current calendar UI: forms, day grids and "Today"
    # use UTC. Database timestamps are also stored as UTC instants.
    # Do not switch this to a regional zone without a separate, reviewed
    # DST-aware display/input design and migration plan.
    config.time_zone = "UTC"
    config.active_record.default_timezone = :utc

    # Enforce same-origin checks for authenticated form mutations when CSRF
    # protection is enabled; the test-only opt-in exercises this HTTP path.
    config.action_controller.forgery_protection_origin_check = true

    # config.eager_load_paths << Rails.root.join("extras")
  end
end
