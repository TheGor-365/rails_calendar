require "test_helper"

if ENV["CI"] && ENV["CI_CHROMEDRIVER_VERSION"].present?
  # webdrivers 5.2.0 queries the deprecated pre-Chrome-115 download endpoint.
  # CI provides a matching Chrome/ChromeDriver pair so no network lookup is needed.
  Webdrivers::Chromedriver.required_version = ENV.fetch("CI_CHROMEDRIVER_VERSION")
end

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driver = ENV["CI"] ? :headless_chrome : :chrome
  driven_by :selenium, using: driver, screen_size: [1400, 1400]
end
