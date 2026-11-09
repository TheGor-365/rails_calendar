source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

# RC-003: supported runtime and patched Rails security release (2026-11-04).
ruby "3.4.12"
gem "rails", "= 8.1.4.1"
gem "bcrypt", "~> 3.1.22"

gem "sprockets-rails"
gem "pg", "~> 1.5"
gem "puma", "~> 8.0", ">= 8.0.2"
gem "jsbundling-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "cssbundling-rails"
gem "jbuilder"
gem "tzinfo-data", platforms: %i[ mingw mswin x64_mingw jruby ]
gem "bootsnap", require: false
gem "simple_calendar", "~> 2.4"

group :development, :test do
  gem "debug", platforms: %i[ mri mingw x64_mingw ]
end

group :development do
  gem "web-console"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
  # Removed the obsolete webdrivers gem. CI installs matching ChromeDriver.
end
