ENV["RAILS_ENV"] ||= "test"

# Test-only fixture credentials. NEVER use these in a deployed environment.
ENV["RAILS_CALENDAR_ADMIN_USERNAME"] ||= "test-admin"
ENV["RAILS_CALENDAR_ADMIN_PASSWORD"] ||= "test-only-not-for-deployment-password"

require_relative "../config/environment"
require "rails/test_help"

class ActiveSupport::TestCase
  parallelize(workers: :number_of_processors)
  fixtures :all

  # Keep the per-process demo login limiter from leaking counters between
  # unrelated tests that sign in from the same default localhost address.
  setup do
    Admin::SessionsController::LOGIN_RATE_LIMIT_STORE.clear
  end
end
