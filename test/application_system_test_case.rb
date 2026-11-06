require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driver = ENV["CI"] ? :headless_chrome : :chrome

  driven_by :selenium, using: driver, screen_size: [1400, 1400] do |options|
    if ENV["CI"] && ENV["WD_CHROME_PATH"].present?
      options.binary = ENV.fetch("WD_CHROME_PATH")
      options.add_argument("--no-sandbox")
      options.add_argument("--disable-dev-shm-usage")
    end
  end
end
