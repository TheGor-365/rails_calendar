ENV["RAILS_ENV"] ||= "test"

# Test-only fixture credentials. NEVER use these in a deployed environment.
ENV["RAILS_CALENDAR_ADMIN_USERNAME"] ||= "test-admin"
ENV["RAILS_CALENDAR_ADMIN_PASSWORD"] ||= "test-only-not-for-deployment-password"

require_relative "../config/environment"
require "rails/test_help"

class ActiveSupport::TestCase
  parallelize(workers: :number_of_processors)
  fixtures :all

  # Reset only this worker's isolated test database counters; never touch
  # development/production data. Fixtures are independent per worker.
  setup do
    AdminLoginWindow.delete_all
  end
end
