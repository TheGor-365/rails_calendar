require "test_helper"

# Selenium Manager is native to Selenium 4. The deprecated webdrivers gem must
# not be loaded or used, especially with modern Chrome (>= 115).
if ENV["CI"] && ENV["CI_CHROMEDRIVER_PATH"].present?
  Selenium::WebDriver::Chrome::Service.driver_path = ENV.fetch("CI_CHROMEDRIVER_PATH")
end

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driver = ENV["CI"] ? :headless_chrome : :chrome

  driven_by :selenium, using: driver, screen_size: [1400, 1400] do |options|
    if ENV["CI"] && ENV["CI_CHROME_PATH"].present?
      options.binary = ENV.fetch("CI_CHROME_PATH")
      options.add_argument("--no-sandbox")
      options.add_argument("--disable-dev-shm-usage")
    end
  end
end
